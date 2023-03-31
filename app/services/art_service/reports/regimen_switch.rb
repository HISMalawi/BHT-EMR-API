# frozen_string_literal: true

module ARTService
  module Reports
    class RegimenSwitch
      def initialize(start_date:, end_date:)
        @start_date = start_date
        @end_date = end_date
      end

      def regimen_switch(pepfar)
        swicth_report(pepfar)
      end

      def regimen_report(type)
        ARTService::Reports::RegimenDispensationData.new(type: type, start_date: @start_date, end_date: @end_date).find_report
      end

      def latest_regimen_dispensed(rebuild_outcome)
        if rebuild_outcome
          cohort_list = ARTService::Reports::CohortBuilder.new(outcomes_definition: 'moh')
          cohort_list.create_tmp_patient_table
          cohort_list.load_data_into_temp_earliest_start_date(@end_date.to_date)

          outcomes = ARTService::Reports::Cohort::Outcomes.new(end_date: @end_date.to_date, definition: 'moh')
          outcomes.update_cummulative_outcomes
        end

        latest_regimens
      end

      private

      def latest_regimens
        pills_dispensed = ConceptName.find_by_name('Amount of drug dispensed').concept_id
        patient_identifier_type = PatientIdentifierType.find_by_name('ARV Number').id

        arv_dispensentions = ActiveRecord::Base.connection.select_all <<~SQL
          SELECT
            o.patient_id, drug.drug_id, o.order_id, i.identifier,
            drug.name, d.quantity, o.start_date, obs.value_numeric,
            person.birthdate, person.gender
          FROM orders o
          INNER JOIN drug_order d ON d.order_id = o.order_id
          INNER JOIN drug ON drug.drug_id = d.drug_inventory_id
          INNER JOIN arv_drug On arv_drug.drug_id = drug.drug_id
          INNER JOIN temp_patient_outcomes t ON o.patient_id = t.patient_id
          INNER JOIN person ON person.person_id = o.patient_id
          LEFT JOIN obs on obs.order_id = o.order_id AND obs.concept_id=#{pills_dispensed}
          LEFT JOIN patient_identifier i ON i.patient_id = o.patient_id
          AND i.identifier_type = #{patient_identifier_type}
          WHERE d.quantity > 0 AND o.voided = 0 AND DATE(o.start_date) = (
            SELECT DATE(MAX(start_date)) FROM orders
            INNER JOIN drug_order t USING(order_id)
            WHERE patient_id = o.patient_id
            AND start_date <= '#{@end_date.to_date.strftime("%Y-%m-%d 23:59:59")}' AND quantity > 0
          ) AND person.voided = 0 AND i.voided = 0 AND t.cum_outcome = 'On antiretrovirals';
        SQL

        formated_data = {}

        (arv_dispensentions || []).each do |data|
          patient_id = data['patient_id'].to_i
          dispensation_date = data['start_date'].to_date
          order_id = data['order_id'].to_i
          drug_id = data['drug_id'].to_i
          medication = data['name']
          quantity = data['quantity'].to_f
          value_numeric = data['value_numeric'].to_f
          drug_id = data['drug_id'].to_i

          formated_data[patient_id] = {} if formated_data[patient_id].blank?
          formated_data[patient_id][order_id] = {
            name: medication,
            quantity: quantity,
            dispensation_date: dispensation_date,
            identifier: data['identifier'],
            gender: data['gender'],
            birthdate: data['birthdate'],
            drug_id: drug_id,
            pack_sizes: []
          } if formated_data[patient_id][order_id].blank?

          formated_data[patient_id][order_id][:pack_sizes] << value_numeric
        end

        return formated_data
      end

      def regimen_data
        encounter_type_id = EncounterType.find_by_name('DISPENSING').id
        arv_concept_id = ConceptName.find_by_name('Antiretroviral drugs').concept_id

        drug_ids = Drug.joins('INNER JOIN concept_set s ON s.concept_id = drug.concept_id')\
                       .where('s.concept_set = ?', arv_concept_id).map(&:drug_id)

        ActiveRecord::Base.connection.execute('drop table if exists tmp_latest_arv_dispensation ;')

        ActiveRecord::Base.connection.execute("
          create table tmp_latest_arv_dispensation
          SELECT patient_id,DATE(MAX(start_date)) as start_date
          FROM orders INNER JOIN drug_order t USING (order_id)
          WHERE
          (
            start_date BETWEEN '#{@start_date.to_date.strftime('%Y-%m-%d 00:00:00')}' AND '#{@end_date.to_date.strftime('%Y-%m-%d 23:59:59')}'
            AND t.drug_inventory_id IN (#{drug_ids.join(',')}) AND t.quantity > 0
          )
          group by patient_id")

        ActiveRecord::Base.connection.execute('create index lad_patient_id_and_start_date on tmp_latest_arv_dispensation (start_date, patient_id);')

        arv_dispensentions = ActiveRecord::Base.connection.select_all <<~SQL
          SELECT
            o.patient_id patient_id, o.start_date,  o.order_id,
            d.quantity, drug.name
          FROM orders o
          INNER JOIN drug_order d ON o.order_id = d.order_id
          INNER JOIN drug ON d.drug_inventory_id = drug.drug_id
          INNER JOIN tmp_latest_arv_dispensation k on (o.patient_id = k.patient_id and DATE(o.start_date) =  k.start_date)
          WHERE d.drug_inventory_id IN(#{drug_ids.join(',')})
          AND d.quantity > 0 AND o.voided = 0 AND o.start_date BETWEEN '#{@start_date.to_date.strftime('%Y-%m-%d 00:00:00')}'
          AND '#{@end_date.to_date.strftime('%Y-%m-%d 23:59:59')}' GROUP BY o.order_id;
        SQL

        patient_ids = []
        (arv_dispensentions || []).each do |data|
          patient_ids << data['patient_id'].to_i
        end
        return [] if patient_ids.blank?

        ActiveRecord::Base.connection.select_all <<~SQL
           SELECT
            `p`.`patient_id` AS `patient_id`,
            cast(patient_date_enrolled(`p`.`patient_id`) as date) AS `date_enrolled`,
            date_antiretrovirals_started(`p`.`patient_id`, min(`s`.`start_date`)) AS `earliest_start_date`
           FROM
              ((`patient_program` `p`
              LEFT JOIN `person` `pe` ON ((`pe`.`person_id` = `p`.`patient_id`))
              LEFT JOIN `patient_state` `s` ON ((`p`.`patient_program_id` = `s`.`patient_program_id`)))
              LEFT JOIN `person` ON ((`person`.`person_id` = `p`.`patient_id`)))
           WHERE
            ((`p`.`voided` = 0)
            AND (`s`.`voided` = 0)
            AND (`p`.`program_id` = 1)
            AND (`s`.`state` = 7))
            AND (`s`.`start_date` <= '#{@end_date.to_date.strftime('%Y-%m-%d 23:59:59')}'
            AND p.patient_id IN(#{patient_ids.join(',')}))
          GROUP BY `p`.`patient_id`;
        SQL
      end

      def arv_dispensention_data(patient_id)
        encounter_type_id = EncounterType.find_by_name('DISPENSING').id
        arv_concept_id = ConceptName.find_by_name('Antiretroviral drugs').concept_id

        drug_ids = Drug.joins('INNER JOIN concept_set s ON s.concept_id = drug.concept_id')\
                       .where('s.concept_set = ?', arv_concept_id).map(&:drug_id)

        ActiveRecord::Base.connection.select_all <<EOF
        SELECT
          o.patient_id,  drug.name, d.quantity, o.start_date
        FROM orders o
        INNER JOIN drug_order d ON d.order_id = o.order_id
        INNER JOIN drug ON drug.drug_id = d.drug_inventory_id
        WHERE d.drug_inventory_id IN(#{drug_ids.join(',')})
        AND o.patient_id = #{patient_id} AND
        d.quantity > 0 AND o.voided = 0 AND DATE(o.start_date) = (
          SELECT DATE(MAX(start_date)) FROM orders
          INNER JOIN drug_order t USING(order_id)
          WHERE patient_id = o.patient_id
          AND (
            start_date BETWEEN '#{@start_date.to_date.strftime('%Y-%m-%d 00:00:00')}'
            AND '#{@end_date.to_date.strftime('%Y-%m-%d 23:59:59')}'
            AND t.drug_inventory_id IN(#{drug_ids.join(',')}) AND quantity > 0
          )
        ) GROUP BY (o.order_id);
EOF
      end

      def current_regimen(type)
        data = regimen_data

        clients = {}
        (data || []).each do |r|
          patient_id = r['patient_id'].to_i

          outcome_status = if type == 'pepfar'
                             ActiveRecord::Base.connection.select_one <<~SQL
                               SELECT pepfar_patient_outcome(#{patient_id}, '#{@end_date.to_date}') outcome;
                             SQL

                           else
                             ActiveRecord::Base.connection.select_one <<~SQL
                               SELECT patient_outcome(#{patient_id}, '#{@end_date.to_date}') outcome;
                             SQL

                           end
          next unless outcome_status['outcome'] == 'On antiretrovirals'

          medications = arv_dispensention_data(patient_id)

          begin
            visit_date = medications.first['start_date'].to_date
          rescue StandardError
            next
          end

          curr_reg = ActiveRecord::Base.connection.select_one <<~SQL
            SELECT patient_current_regimen(#{patient_id}, '#{@end_date.to_date}') current_regimen
          SQL

          next unless visit_date >= @start_date.to_date && visit_date <= @end_date.to_date

          if clients[patient_id].blank?
            demo = ActiveRecord::Base.connection.select_one <<~SQL
              SELECT
                p.birthdate, p.gender, i.identifier arv_number,
                n.given_name, n.family_name
              FROM person p
              LEFT JOIN person_name n ON n.person_id = p.person_id AND n.voided = 0
              LEFT JOIN patient_identifier i ON i.patient_id = p.person_id
              AND i.identifier_type = 4 AND i.voided = 0
              WHERE p.person_id = #{patient_id} GROUP BY p.person_id
              ORDER BY n.date_created DESC, i.date_created DESC;
            SQL

            viral_load = vl_result(patient_id)
            clients[patient_id] = {
              arv_number: demo['arv_number'],
              given_name: demo['given_name'],
              family_name: demo['family_name'],
              birthdate: demo['birthdate'],
              gender: demo['gender'] == 'M' ? 'M' : maternal_status(patient_id, demo['gender']),
              current_regimen: curr_reg['current_regimen'],
              current_weight: current_weight(patient_id),
              art_start_date: r['earliest_start_date'],
              medication: [],
              vl_result: viral_load ? viral_load['result'] : nil,
              vl_result_date: viral_load ? viral_load['result_date'] : nil
            }
          end

          (medications || []).each do |med|
            clients[patient_id][:medication] << {
              medication: med['name'],
              quantity: med['quantity'],
              start_date: visit_date
            }
          end
        end

        clients
      end

      def swicth_report(pepfar)
        clients = {}
        data = regimen_data
        pepfar_outcome_builder(pepfar.blank? ? 'moh' : 'pepfar')

        (data || []).each do |r|
          patient_id = r['patient_id'].to_i
          medications = arv_dispensention_data(patient_id)


          outcome_status = ActiveRecord::Base.connection.select_one <<~SQL
            SELECT cum_outcome FROM temp_patient_outcomes WHERE patient_id = #{patient_id};
          SQL

          next if outcome_status.blank?
          next if outcome_status['cum_outcome'].blank?
          next unless outcome_status['cum_outcome'] == 'On antiretrovirals'

          visit_date = medications.first['start_date']
          visit_date.blank? ? next : (visit_date = visit_date.to_date)

          next unless visit_date >= @start_date.to_date && visit_date <= @end_date.to_date

          prev_reg = ActiveRecord::Base.connection.select_one <<EOF
          SELECT patient_current_regimen(#{patient_id}, '#{(visit_date - 1.day).to_date}') previous_regimen
EOF

          current_reg = ActiveRecord::Base.connection.select_one <<EOF
          SELECT patient_current_regimen(#{patient_id}, '#{visit_date}') current_regimen
EOF

          next if prev_reg['previous_regimen'] == current_reg['current_regimen']
          next if prev_reg['previous_regimen'] == 'N/A'

          if clients[patient_id].blank?
            demo = ActiveRecord::Base.connection.select_one <<EOF
            SELECT
              p.birthdate, p.gender, i.identifier arv_number,
              n.given_name, n.family_name, p.person_id
            FROM person p
            LEFT JOIN person_name n ON n.person_id = p.person_id AND n.voided = 0
            LEFT JOIN patient_identifier i ON i.patient_id = p.person_id
            AND i.identifier_type = 4 AND i.voided = 0
            WHERE p.person_id = #{patient_id} GROUP BY p.person_id
            ORDER BY n.date_created DESC, i.date_created DESC;
EOF

            clients[patient_id] = {
              arv_number: (demo['arv_number'].blank? ? 'N/A' : demo['arv_number']),
              given_name: demo['given_name'],
              family_name: demo['family_name'],
              birthdate: demo['birthdate'],
              gender: demo['gender'],
              previous_regimen: prev_reg['previous_regimen'],
              current_regimen: current_reg['current_regimen'],
              patient_type: get_patient_type(demo['person_id'], pepfar),
              current_weight: current_weight(demo['person_id']),
              art_start_date: r['earliest_start_date'],
              medication: []
            }
          end

          (medications || []).each do |m|
            clients[patient_id][:medication] << {
              medication: m['name'], quantity: m['quantity'],
              start_date: visit_date
            }
          end
        end

        clients
      end

      def get_patient_type(patient_id, pepfar)
        return nil unless pepfar

        concept_id = ConceptName.find_by_name('Type of patient').concept_id
        ext_id = ConceptName.find_by_name('External consultation').concept_id
        obs = Observation.where(concept_id: concept_id, value_coded: ext_id, person_id: patient_id)
        (obs.blank? ? 'Resident' : 'External')
      end

      def pepfar_outcome_builder(repport_type = 'moh')
        cohort_builder = ARTService::Reports::CohortDisaggregated.new(name: 'Regimen switch', type: repport_type,
                                                                      start_date: @start_date.to_date, end_date: @end_date.to_date, rebuild: true)
        cohort_builder.rebuild_outcomes(repport_type)
      end

      def current_weight(patient_id)
        weight_concept = ConceptName.find_by_name('Weight (kg)').concept_id
        obs = Observation.where("person_id = ? AND concept_id = ?
          AND obs_datetime <= ? AND (value_numeric IS NOT NULL OR value_text IS NOT NULL)",
                                patient_id, weight_concept, @end_date.to_date.strftime('%Y-%m-%d 23:59:59'))\
                         .order('obs_datetime DESC, date_created DESC')

        return nil if obs.blank?

        (obs.first.value_numeric.blank? ? obs.first.value_text : obs.first.value_numeric)
      end

      def vl_result(patient_id)
        ActiveRecord::Base.connection.select_one <<~SQL
          SELECT lab_result_obs.obs_datetime AS result_date,
          CONCAT (COALESCE(measure.value_modifier, '='),' ',COALESCE(measure.value_numeric, measure.value_text, '')) as result
          FROM obs AS lab_result_obs
          INNER JOIN orders
            ON orders.order_id = lab_result_obs.order_id
            AND orders.voided = 0
          INNER JOIN obs AS measure
            ON measure.obs_group_id = lab_result_obs.obs_id
            AND measure.voided = 0
          INNER JOIN (
            SELECT concept_id, name
            FROM concept_name
            INNER JOIN concept USING (concept_id)
            WHERE concept.retired = 0
            AND name NOT LIKE 'Lab test result'
            GROUP BY concept_id
          ) AS measure_concept
            ON measure_concept.concept_id = measure.concept_id
          WHERE lab_result_obs.voided = 0
          AND measure.person_id = #{patient_id}
          AND (measure.value_numeric IS NOT NULL || measure.value_text IS NOT NULL)
          AND lab_result_obs.obs_datetime <= '#{@end_date.to_date.strftime('%Y-%m-%d 23:59:59')}'
          ORDER BY lab_result_obs.obs_datetime DESC
          LIMIT 1
        SQL
      end

      def maternal_status(patient_id, current_gender)
        return nil if current_gender.blank?

        result = ARTService::Reports::Pepfar::ViralLoadCoverage2.new(start_date: @start_date, end_date: @end_date).vl_maternal_status([patient_id])
        gender = 'FNP'
        gender = 'FP' unless result[:FP].blank?
        gender = 'FBf' unless result[:FBf].blank?
        gender
      end
    end
  end
end
