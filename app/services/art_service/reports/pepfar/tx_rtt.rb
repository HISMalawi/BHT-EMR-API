module ARTService
  module Reports
    module Pepfar

      class TxRTT
        def initialize(start_date:, end_date:)
          @start_date = start_date.to_date.strftime('%Y-%m-%d 00:00:00')
          @end_date = end_date.to_date.strftime('%Y-%m-%d 23:59:59')
        end

        def data
          return tx_rtt
        end


        private

        def tx_rtt
          data  = {}
          patient_data  = get_tx_rtt_clients
          patients  = []

          (patient_data || []).each do |pat|
            patients << [ pat['patient_id'].to_i, pat['age_group'], pat['gender'] ]
          end

          return [] if patients.blank?

          (patients || []).each do |patient_id, age_group, sex|
            gender = sex.upcase.first rescue 'Unknown'

            if data[age_group].blank?
              data[age_group]= {}
              data[age_group][gender] = []
            elsif data[age_group][gender].blank?
              data[age_group][gender] = []
            end

            data[age_group][gender] << patient_id
          end

          return data
        end

        def get_tx_rtt_clients
          return ActiveRecord::Base.connection.select_all <<~SQL
          SELECT o.patient_id, p.gender,
            cohort_disaggregated_age_group(p.birthdate, DATE('#{@end_date}')) age_group,
            pepfar_patient_outcome(p.person_id, DATE('#{@start_date.to_date -  1.day}')) outcome
          FROM  orders o
          INNER JOIN encounter e ON e.encounter_id = o.encounter_id AND e.program_id = 1
          INNER JOIN drug_order t On t.order_id = o.order_id
          INNER JOIN drug d ON d.drug_id  = t.drug_inventory_id
          INNER JOIN concept_set s ON s.concept_id = d.concept_id AND s.concept_set  = 1085
          INNER JOIN person p ON p.person_id = o.patient_id
          WHERE o.voided = 0 AND o.start_date BETWEEN '#{@start_date}' AND '#{@end_date}' AND t.quantity > 0
          AND pepfar_patient_outcome(p.person_id, DATE('#{@end_date}')) = 'On antiretrovirals'
          GROUP BY o.patient_id HAVING outcome != 'On antiretrovirals' AND
          outcome NOT LIKE '%transf%' AND outcome != 'Unknown';
          SQL

        end

      end




    end
  end
end
