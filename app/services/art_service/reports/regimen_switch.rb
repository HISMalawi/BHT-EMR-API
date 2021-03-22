# frozen_string_literal: true

module ARTService
  module Reports

    class RegimenSwitch
      def initialize(start_date:, end_date:)
        @start_date = start_date
        @end_date = end_date
      end

      def regimen_switch(pepfar)
        return swicth_report(pepfar)
      end

      def regimen_report(type)
        return current_regimen(type)
      end

      private

      def regimen_data
        encounter_type_id = EncounterType.find_by_name('DISPENSING').id
        arv_concept_id  = ConceptName.find_by_name('Antiretroviral drugs').concept_id

        drug_ids = Drug.joins('INNER JOIN concept_set s ON s.concept_id = drug.concept_id').\
          where("s.concept_set = ?", arv_concept_id).map(&:drug_id)

        arv_dispensentions = ActiveRecord::Base.connection.select_all <<~SQL
            SELECT
              o.patient_id patient_id, o.start_date,  o.order_id,
              d.quantity, drug.name
            FROM orders o
            INNER JOIN drug_order d ON d.order_id = o.order_id
            INNER JOIN drug ON drug.drug_id = d.drug_inventory_id
            WHERE d.drug_inventory_id IN(#{drug_ids.join(',')})
            AND d.quantity > 0 AND o.voided = 0 AND DATE(o.start_date) = (
              SELECT DATE(MAX(start_date)) FROM orders
              INNER JOIN drug_order t USING(order_id)
              WHERE patient_id = o.patient_id
              AND (
                start_date BETWEEN '#{@start_date.to_date.strftime('%Y-%m-%d 00:00:00')}'
                AND '#{@end_date.to_date.strftime('%Y-%m-%d 23:59:59')}'
                AND t.drug_inventory_id IN(#{drug_ids.join(',')}) AND quantity > 0
              )
            ) AND o.start_date BETWEEN '#{@start_date.to_date.strftime('%Y-%m-%d 00:00:00')}'
            AND '#{@end_date.to_date.strftime('%Y-%m-%d 23:59:59')}' GROUP BY o.order_id;
        SQL

        patient_ids = []
        (arv_dispensentions||[]).each{|data|
          patient_ids  << data['patient_id'].to_i
        }
        return [] if patient_ids.blank?

        return ActiveRecord::Base.connection.select_all <<~SQL
       SELECT
        `p`.`patient_id` AS `patient_id`
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
        arv_concept_id  = ConceptName.find_by_name('Antiretroviral drugs').concept_id

        drug_ids = Drug.joins('INNER JOIN concept_set s ON s.concept_id = drug.concept_id').\
          where("s.concept_set = ?", arv_concept_id).map(&:drug_id)

         return ActiveRecord::Base.connection.select_all <<EOF
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

          if type == "pepfar"
            outcome_status = ActiveRecord::Base.connection.select_one <<~SQL
              SELECT pepfar_patient_outcome(#{patient_id}, '#{(@end_date).to_date}') outcome;
            SQL

          else
            outcome_status = ActiveRecord::Base.connection.select_one <<~SQL
              SELECT patient_outcome(#{patient_id}, '#{(@end_date).to_date}') outcome;
            SQL

          end
          next unless outcome_status['outcome'] == 'On antiretrovirals'

          medications = arv_dispensention_data(patient_id)

          begin
            visit_date = medications.first['start_date'].to_date
          rescue
            next
          end

          curr_reg = ActiveRecord::Base.connection.select_one <<EOF
          SELECT patient_current_regimen(#{patient_id}, '#{(@end_date).to_date}') current_regimen
EOF

          next unless (visit_date >= @start_date.to_date && visit_date <= @end_date.to_date)

          if clients[patient_id].blank?
            demo = ActiveRecord::Base.connection.select_one <<EOF
            SELECT
              p.birthdate, p.gender, i.identifier arv_number,
              n.given_name, n.family_name
            FROM person p
            LEFT JOIN person_name n ON n.person_id = p.person_id AND n.voided = 0
            LEFT JOIN patient_identifier i ON i.patient_id = p.person_id
            AND i.identifier_type = 4 AND i.voided = 0
            WHERE p.person_id = #{patient_id} GROUP BY p.person_id
            ORDER BY n.date_created DESC, i.date_created DESC;
EOF

            clients[patient_id] = {
              arv_number: demo['arv_number'],
              given_name: demo['given_name'],
              family_name: demo['family_name'],
              birthdate: demo['birthdate'],
              gender: demo['gender'],
              current_regimen: curr_reg['current_regimen'],
              current_weight: current_weight(patient_id),
              medication: []
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

        return clients
      end

      def swicth_report(pepfar)
        clients = {}
        data = regimen_data
        pepfar_outcome_builder if pepfar

        (data || []).each do |r|
          patient_id = r['patient_id'].to_i
          medications = arv_dispensention_data(patient_id)

          if pepfar
            outcome_status = ActiveRecord::Base.connection.select_one <<EOF
          SELECT patient_pepfar_outcome(#{patient_id}, '#{(@end_date).to_date}') outcome;
EOF

          else
            outcome_status = ActiveRecord::Base.connection.select_one <<EOF
          SELECT patient_outcome(#{patient_id}, '#{(@end_date).to_date}') outcome;
EOF

          end

          next unless outcome_status['outcome'] == 'On antiretrovirals'

          begin
            visit_date = medications.first['start_date'].to_date
          rescue
            next
          end

          next unless (visit_date >= @start_date.to_date && visit_date <= @end_date.to_date)

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
              arv_number: demo['arv_number'],
              given_name: demo['given_name'],
              family_name: demo['family_name'],
              birthdate: demo['birthdate'],
              gender: demo['gender'],
              previous_regimen: prev_reg['previous_regimen'],
              current_regimen: current_reg['current_regimen'],
              patient_type: get_patient_type(demo['person_id'], pepfar),
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

        return clients
      end

      def get_patient_type(patient_id, pepfar)
        return nil unless pepfar
        concept_id = ConceptName.find_by_name('Type of patient').concept_id
        ext_id = ConceptName.find_by_name('External consultation').concept_id
        obs = Observation.where(concept_id: concept_id, value_coded: ext_id, person_id: patient_id)
        return (obs.blank? ? 'Resident' : 'External')
      end

      def pepfar_outcome_builder
        cohort_builder = ARTService::Reports::CohortDisaggregated.new(name: 'Regimen switch', type: 'pepfar',
        start_date: @start_date.to_date, end_date: @end_date.to_date, rebuild: true)
        cohort_builder.create_mysql_pepfar_current_defaulter
        cohort_builder.create_mysql_pepfar_current_outcome
      end

      def current_weight(patient_id)
        weight_concept = ConceptName.find_by_name("Weight (kg)").concept_id
        obs = Observation.where("person_id = ? AND concept_id = ?
          AND obs_datetime <= ? AND (value_numeric IS NOT NULL OR value_text IS NOT NULL)",
            patient_id, weight_concept, @end_date.to_date.strftime("%Y-%m-%d 23:59:59"))\
              .order("obs_datetime DESC, date_created DESC")

        return nil if obs.blank?
        return (obs.first.value_numeric.blank? ? obs.first.value_text : obs.first.value_numeric)
      end

    end
  end

end
