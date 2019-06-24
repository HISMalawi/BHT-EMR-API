# frozen_string_literal: true

module ARTService
  module Reports

    class RegimenSwitch
      def initialize(start_date:, end_date:)
        @start_date = start_date
        @end_date = end_date
      end

      def regimen_switch
        return swicth_report
      end

      def regimen_report
        return current_regimen
      end

      private 
      
      def current_regimen
        encounter_type_id = EncounterType.find_by_name('DISPENSING').id
        arv_concept_id  = ConceptName.find_by_name('Antiretroviral drugs').concept_id

        drug_ids = Drug.joins('INNER JOIN concept_set s ON s.concept_id = drug.concept_id').\
          where("s.concept_set = ?", arv_concept_id).map(&:drug_id)
          
        data = ActiveRecord::Base.connection.select_all <<EOF
        SELECT 
          e.patient_id,  drug.name, d.quantity, o.start_date
        FROM encounter e
        INNER JOIN orders o ON e.patient_id = o.patient_id
        INNER JOIN drug_order d ON d.order_id = o.order_id
        INNER JOIN drug ON drug.drug_id = d.drug_inventory_id
        WHERE d.drug_inventory_id IN(#{drug_ids.join(',')})
        AND e.encounter_type = #{encounter_type_id}
        AND d.quantity > 0 AND o.voided = 0 AND o.start_date = (
          SELECT MAX(start_date) FROM orders 
          WHERE order_id = o.order_id 
          AND (start_date BETWEEN '#{@start_date.to_date.strftime('%Y-%m-%d 00:00:00')}' 
          AND '#{@end_date.to_date.strftime('%Y-%m-%d 23:59:59')}')
        ) GROUP BY (o.order_id);
EOF
   
        clients = {}
        (data || []).each do |r|
          patient_id = r['patient_id']
          visit_date = r['start_date'].to_date
          outcome = ActiveRecord::Base.connection.select_one <<EOF
          SELECT patient_outcome(#{patient_id}, DATE('#{@end_date.to_date}')) as status;
EOF
    
          outcome = outcome['status'];
          next unless outcome == 'On antiretrovirals'
           
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

          
          clients[patient_id][:medication] << {
            medication: r['name'], quantity: r['quantity'],
            start_date: visit_date
          }
        end

        return clients
      end

      def swicth_report
        encounter_type_id = EncounterType.find_by_name('DISPENSING').id
        arv_concept_id  = ConceptName.find_by_name('Antiretroviral drugs').concept_id

        drug_ids = Drug.joins('INNER JOIN concept_set s ON s.concept_id = drug.concept_id').\
          where("s.concept_set = ?", arv_concept_id).map(&:drug_id)
          
        data = ActiveRecord::Base.connection.select_all <<EOF
        SELECT 
          e.patient_id,  drug.name, d.quantity, o.start_date
        FROM encounter e
        INNER JOIN orders o ON e.patient_id = o.patient_id
        INNER JOIN drug_order d ON d.order_id = o.order_id
        INNER JOIN drug ON drug.drug_id = d.drug_inventory_id
        WHERE d.drug_inventory_id IN(#{drug_ids.join(',')})
        AND e.encounter_type = #{encounter_type_id}
        AND d.quantity > 0 AND o.voided = 0 AND o.start_date = (
          SELECT MAX(start_date) FROM orders 
          WHERE order_id = o.order_id 
          AND (start_date BETWEEN '#{@start_date.to_date.strftime('%Y-%m-%d 00:00:00')}' 
          AND '#{@end_date.to_date.strftime('%Y-%m-%d 23:59:59')}')
        ) GROUP BY (o.order_id);
EOF
   
        clients = {}
        (data || []).each do |r|
          patient_id = r['patient_id']
          visit_date = r['start_date'].to_date
          outcome = ActiveRecord::Base.connection.select_one <<EOF
          SELECT patient_outcome(#{patient_id}, DATE('#{@end_date.to_date}')) as status;
EOF
    
          outcome = outcome['status'];
          next unless outcome == 'On antiretrovirals'
           
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
              previous_regimen: prev_reg['previous_regimen'],
              current_regimen: current_reg['current_regimen'],
              medication: []
            }
          end

          
          clients[patient_id][:medication] << {
            medication: r['name'], quantity: r['quantity'],
            start_date: visit_date
          }
        end

        return clients
      end


    end
  end

end
