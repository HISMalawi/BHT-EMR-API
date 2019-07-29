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

      def regimen_report
        return current_regimen
      end

      private 
      
      def regimen_data
        art_service = ARTService::Reports::CohortBuilder.new()
        art_service.create_tmp_patient_table
        art_service.load_data_into_temp_earliest_start_date(@end_date) 
        art_service.update_cum_outcome(@end_date)

       return ActiveRecord::Base.connection.select_all <<EOF
       SELECT e.* FROM temp_earliest_start_date e
       INNER JOIN temp_patient_outcomes USING(patient_id)
       WHERE cum_outcome = 'On antiretrovirals';
EOF

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
    
    def current_regimen 
      data = regimen_data

        clients = {}
        (data || []).each do |r|
          patient_id = r['patient_id'].to_i
          medications = arv_dispensention_data(patient_id)
          visit_date = medications.first['start_date'].to_date
          
          curr_reg = ActiveRecord::Base.connection.select_one <<EOF
          SELECT patient_current_regimen(#{patient_id}, '#{(@end_date).to_date}') current_regimen
EOF

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

      def swicth_report(pepfar)
        clients = {}
        data = regimen_data

        (data || []).each do |r|
          patient_id = r['patient_id'].to_i
          medications = arv_dispensention_data(patient_id)
          visit_date = medications.first['start_date'].to_date
           
          prev_reg = ActiveRecord::Base.connection.select_one <<EOF
          SELECT patient_current_regimen(#{patient_id}, '#{(visit_date - 1.day).to_date}') previous_regimen
EOF

          current_reg = ActiveRecord::Base.connection.select_one <<EOF
          SELECT patient_current_regimen(#{patient_id}, '#{visit_date}') current_regimen
EOF

          unless pepfar
            next if prev_reg['previous_regimen'] == current_reg['current_regimen']
            next if prev_reg['previous_regimen'] == 'N/A'
          end

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

    end
  end

end
