# frozen_string_literal: true

module ArtService
  module Reports
    class ArvRefillPeriods
      def initialize(start_date:, end_date:, min_age:, max_age:, org:, initialize_tables:, **kwargs)
        @start_date = start_date.to_date.strftime('%Y-%m-%d 00:00:00')
        @end_date = end_date.to_date.strftime('%Y-%m-%d 23:59:59')
        @min_age = min_age
        @max_age = max_age
        @org = org
        @initialize_tables = (initialize_tables == 'true')
        @occupation = kwargs[:occupation]
      end

      def arv_refill_periods
        break_down
      end

      def tx_mmd_client_level_data(patient_ids)
        client_level_data(patient_ids)
      end

      private

      def break_down
        program_id = Program.find_by(name: 'HIV PROGRAM').id
        arv_concept_set = ConceptName.find_by(name: 'ARVS').concept_id
        encounter_type = EncounterType.find_by(name: 'DISPENSING').id

        if @initialize_tables
          report_type = (@org.match(/pepfar/i) ? 'pepfar' : 'moh')
          ArtService::Reports::CohortBuilder.new(outcomes_definition: report_type).init_temporary_tables(@start_date,
                                                                                                         @end_date, @occupation)
        end

        patients = ActiveRecord::Base.connection.select_all <<~SQL
          SELECT
            p.patient_id, p.date_enrolled, p.birthdate, p.gender,
            outcome.cum_outcome AS outcome
          FROM temp_earliest_start_date p
          LEFT JOIN temp_patient_outcomes outcome USING(patient_id)
          WHERE DATE(date_enrolled) <= DATE('#{@end_date}')
          AND TIMESTAMPDIFF(year, p.birthdate, DATE('#{@end_date}')) BETWEEN #{@min_age} AND #{@max_age}
          AND cum_outcome = 'On antiretrovirals';
        SQL

        return {} if patients.blank?

        data = []
        patients.each do |p|
          data  << [p['patient_id'].to_i, p['gender'], p['birthdate']]
        end

        results = {}
        (data || []).each do |patient_id, sex, birthdate|
          gender = (sex.blank? ? 'Unknown' : sex)
          if gender != 'Unknown'
            gender = (gender.match(/F/i) ? 'Female' : 'Male')
          end

          # birthdate = birthdate
          results[gender] = {} if results[gender].blank?

          dispensing_info = get_dispensing_info(patient_id,
                                                encounter_type, arv_concept_set, program_id)

          results[gender][patient_id] = {
            prescribed_days: dispensing_info,
            birthdate:, gender:
          }
        end

        results
      end

      def get_dispensing_info(patient_id, encounter_type,
                              arv_concept_set, program_id)

        data = ActiveRecord::Base.connection.select_all <<~SQL
          SELECT
            o.patient_id, p.gender, p.birthdate, o.start_date,
            o.auto_expire_date, d.name, quantity, d.drug_id,
            TIMESTAMPDIFF(day, DATE(o.start_date), DATE(o.auto_expire_date)) prescribed_days
          FROM orders o
          INNER JOIN drug_order od ON od.order_id = o.order_id
          INNER JOIN drug d ON d.drug_id = od.drug_inventory_id
          INNER JOIN concept_set s ON s.concept_id = d.concept_id
          INNER JOIN person p ON p.person_id = o.patient_id
          INNER JOIN encounter e ON e.patient_id = p.person_id
          WHERE s.concept_set = #{arv_concept_set} AND o.voided = 0
          AND DATE(o.start_date) = (
            SELECT DATE(MAX(t.start_date)) FROM orders t
            INNER JOIN drug_order t2 ON t2.order_id = t.order_id
            INNER JOIN drug t3 ON t3.drug_id = t2.drug_inventory_id
            INNER JOIN concept_set t4 ON t4.concept_id = t3.concept_id
            WHERE t.patient_id = #{patient_id}
            AND t.voided = 0 AND t.start_date <= '#{@end_date}'
            AND t4.concept_set = #{arv_concept_set} AND t2.quantity > 0
          ) AND e.program_id = #{program_id} AND o.patient_id = #{patient_id}
          AND od.quantity > 0 AND e.encounter_type = #{encounter_type}
          GROUP BY o.order_id;
        SQL

        return if data.blank?

        regimen_info = ActiveRecord::Base.connection.select_one <<~SQL
          SELECT patient_current_regimen(#{patient_id}, DATE('#{@end_date}')) regimen;
        SQL

        regimen = regimen_info['regimen']
        prescribed_days = nil

        unless regimen.match(/N/i)
          weight_sql = get_weight(patient_id)
          regimen_index = regimen.to_i
          moh_regimen_ingredients = ActiveRecord::Base.connection.select_all <<~SQL
            SELECT
              regimen_index, min_weight, max_weight,
              drug_inventory_id, am, pm
            FROM moh_regimens r
            INNER JOIN moh_regimen_ingredient i ON r.regimen_id = i.regimen_id
            AND r.regimen_index = #{regimen_index}
            INNER JOIN moh_regimen_doses d ON i.dose_id = d.dose_id #{weight_sql}
            GROUP BY min_weight, max_weight, drug_inventory_id;
          SQL

          doses = {}
          (moh_regimen_ingredients || []).each do |i|
            drug_id = i['drug_inventory_id'].to_i
            am = i['am'].to_f
            pm = i['pm'].to_f
            doses[drug_id] = (am.to_f + pm.to_f).to_f
          end

          unless doses.blank?
            data.each do |info|
              drug_id = info['drug_id'].to_i
              quantity = info['quantity'].to_f
              dose_per_day = doses[drug_id]
              next if dose_per_day.blank?

              if prescribed_days.blank?
                prescribed_days = (quantity / dose_per_day).to_i
              else
                days = (quantity / dose_per_day).to_i
                prescribed_days = days if days > prescribed_days
              end
            end
          end

          return prescribed_days unless prescribed_days.blank?
        end

        data.each do |info|
          days = (info['prescribed_days'].to_i + 1)
          if prescribed_days.blank?
            prescribed_days = days
          elsif days > prescribed_days
            prescribed_days = days
          end
        end

        prescribed_days
      end

      def get_weight(patient_id)
        concept_id = ConceptName.find_by_name('Weight (Kg)').concept_id
        weight_details = Observation.where("person_id = ? AND concept_id = ?
          AND obs_datetime <= ? AND ( CAST(value_numeric as DECIMAL(4,1)) > 0 OR
          CAST(value_text as DECIMAL(4,1)) > 0)", patient_id,
                                           concept_id, @end_date).order('obs_datetime DESC, date_created DESC')

        return nil if weight_details.blank?

        weight_details = weight_details.first
        weight = (weight_details.value_numeric.to_f.positive? ? weight_details.value_numeric.to_f : weight_details.value_text.to_f)
        " WHERE #{weight} >= min_weight AND #{weight} <= max_weight "
      end

      def client_level_data(patient_ids)
        program_id = Program.find_by(name: 'HIV PROGRAM').id
        arv_concept_set = ConceptName.find_by(name: 'ARVS').concept_id
        encounter_type = EncounterType.find_by(name: 'DISPENSING').id
        identifier_type = PatientIdentifierType.find_by_name('ARV number').id
        info = []

        patient_ids.each do |patient_id|
          info << client_data(patient_id, encounter_type,
                              program_id, arv_concept_set, identifier_type)
        end

        info
      end

      def client_data(patient_id, _encounter_type, program_id, arv_concept_set, identifier_type)
        info = {}
        info[patient_id] = {}

        data = ActiveRecord::Base.connection.select_all <<~SQL
          SELECT
            o.patient_id, p.gender, p.birthdate, o.start_date, e2.earliest_start_date art_start_date,
            o.auto_expire_date, d.name, quantity, d.drug_id, identifier arv_number,
            TIMESTAMPDIFF(day, DATE(o.start_date), DATE(o.auto_expire_date)) prescribed_days
          FROM orders o
          INNER JOIN drug_order od ON od.order_id = o.order_id
          INNER JOIN drug d ON d.drug_id = od.drug_inventory_id
          INNER JOIN concept_set s ON s.concept_id = d.concept_id
          INNER JOIN person p ON p.person_id = o.patient_id
          INNER JOIN encounter e ON e.patient_id = p.person_id
          INNER JOIN temp_earliest_start_date e2 ON e2.patient_id = p.person_id
          AND e.program_id = #{program_id}
          LEFT JOIN patient_identifier i ON  i.patient_id = o.patient_id
          AND i.identifier_type = #{identifier_type}
          AND LENGTH(identifier) > 0 AND i.voided = 0
          WHERE s.concept_set = #{arv_concept_set} AND o.voided = 0
          AND DATE(o.start_date) = (
            SELECT DATE(MAX(t.start_date)) FROM orders t
            INNER JOIN drug_order t2 ON t2.order_id = t.order_id
            INNER JOIN drug t3 ON t3.drug_id = t2.drug_inventory_id
            INNER JOIN concept_set t4 ON t4.concept_id = t3.concept_id
            WHERE t.patient_id = #{patient_id}
            AND t.voided = 0 AND t.start_date <= '#{@end_date}'
            AND t4.concept_set = #{arv_concept_set} AND t2.quantity > 0
          )AND e.program_id = #{program_id} AND o.patient_id = #{patient_id}
          AND od.quantity > 0 GROUP BY o.order_id;
        SQL

        regimen_info = ActiveRecord::Base.connection.select_one <<~SQL
          SELECT patient_current_regimen(#{patient_id}, DATE('#{@end_date}')) regimen;
        SQL

        regimen = regimen_info['regimen']
        regimen = (regimen.match(/N/i) ? 'Unknown' : regimen)

        unless regimen.match(/Unknown/i)
          weight_sql = get_weight(patient_id)
          regimen_index = regimen.to_i
          moh_regimen_ingredients = ActiveRecord::Base.connection.select_all <<~SQL
            SELECT
              regimen_index, min_weight, max_weight,
              drug_inventory_id, am, pm
            FROM moh_regimens r
            INNER JOIN moh_regimen_ingredient i ON r.regimen_id = i.regimen_id
            AND r.regimen_index = #{regimen_index}
            INNER JOIN moh_regimen_doses d ON i.dose_id = d.dose_id #{weight_sql}
            GROUP BY min_weight, max_weight, drug_inventory_id;
          SQL

          doses = {}
          (moh_regimen_ingredients || []).each do |i|
            drug_id = i['drug_inventory_id'].to_i
            am = i['am'].to_f
            pm = i['pm'].to_f
            doses[drug_id] = (am.to_f + pm.to_f).to_f
          end
        end

        info[patient_id][regimen] = {}
        data.each do |i|
          drug_id = i['drug_id'].to_i
          quantity = i['quantity'].to_f
          drug_name  = i['name']
          start_date = i['start_date'].to_date
          auto_expire_date = i['auto_expire_date']
          dose_per_day = begin
            doses[drug_id]
          rescue StandardError
            'N/A'
          end
          quantity = quantity.to_f
          arv_number = i['arv_number']
          birthdate = i['birthdate']

          info[patient_id][regimen][drug_id] = {
            art_start_date: i['art_start_date'].to_date.strftime('%d/%b/%Y'),
            drug_name:,
            start_date: start_date.to_date.strftime('%d/%b/%Y'),
            auto_expire_date: begin
              auto_expire_date.to_date.strftime('%d/%b/%Y')
            rescue StandardError
              nil
            end,
            dose_per_day:,
            quantity:,
            arv_number: (arv_number.blank? ? 'N/A' : arv_number),
            birthdate: begin
              birthdate.to_date.strftime('%d/%b/%Y')
            rescue StandardError
              'N/A'
            end
          }
        end

        info
      end
    end
  end
end