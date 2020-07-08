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
          patient_data  = get_potential_tx_rtt_clients
          patients  = []

          (patient_data || []).each do |pat|
            patients << [ pat['patient_id'].to_i, pat['age_group'], pat['gender'] ]
          end

          return [] if patients.blank?

          (patients || []).each do |patient_id, age_group, sex|
            start_date = maximum_start_date patient_id
            auto_expire_date = maximum_end_date patient_id, start_date
            days = auto_expire_date_start_date_gap(start_date, auto_expire_date)

            next if days.blank?
            next if days <= 30

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

        def get_potential_tx_rtt_clients
          return ActiveRecord::Base.connection.select_all <<-SQL
          SELECT o.patient_id, p.gender,
            cohort_disaggregated_age_group(p.birthdate, DATE('#{@end_date}')) age_group
          FROM  orders o
          INNER JOIN encounter e ON e.encounter_id = o.encounter_id AND e.program_id = 1
          INNER JOIN drug_order t On t.order_id = o.order_id
          INNER JOIN drug d ON d.drug_id  = t.drug_inventory_id
          INNER JOIN concept_set s ON s.concept_id = d.concept_id AND s.concept_set  = 1085
          INNER JOIN person p ON p.person_id = e.patient_id
          WHERE o.voided = 0 AND o.start_date BETWEEN '#{@start_date}' AND '#{@end_date}' AND t.quantity > 0
          AND pepfar_patient_outcome(p.person_id, DATE('#{@end_date}')) = 'On antiretrovirals'
          GROUP BY e.patient_id;
          SQL

        end

        def maximum_start_date(patient_id)
          order_date =  ActiveRecord::Base.connection.select_one <<-SQL
          SELECT MAX(start_date) start_date FROM  orders o
          INNER JOIN encounter e ON e.encounter_id = o.encounter_id AND e.program_id = 1
          INNER JOIN drug_order t On t.order_id = o.order_id
          INNER JOIN drug d ON d.drug_id  = t.drug_inventory_id
          INNER JOIN concept_set s ON s.concept_id = d.concept_id AND s.concept_set  = 1085
          INNER JOIN person p ON p.person_id = e.patient_id
          WHERE o.voided = 0 AND o.start_date BETWEEN '#{@start_date}' AND '#{@end_date}'
          AND p.person_id = #{patient_id} GROUP BY e.patient_id;
          SQL

          return  order_date['start_date'].to_date
        end

        def maximum_end_date(patient_id, start_date)
          order_date =  ActiveRecord::Base.connection.select_one <<-SQL
            SELECT MAX(start_date) start_date  FROM  orders o
            INNER JOIN encounter e ON e.encounter_id = o.encounter_id AND e.program_id = 1
            INNER JOIN drug_order t On t.order_id = o.order_id
            INNER JOIN drug d ON d.drug_id  = t.drug_inventory_id
            INNER JOIN concept_set s ON s.concept_id = d.concept_id AND s.concept_set  = 1085
            INNER JOIN person p ON p.person_id = e.patient_id
            WHERE o.voided = 0 AND DATE(o.start_date) < DATE('#{start_date}')
            AND p.person_id = #{patient_id} GROUP BY e.patient_id;
          SQL

          return if order_date.blank?
          max_date = order_date['start_date'].to_date rescue nil

          auto_expire =  ActiveRecord::Base.connection.select_one <<-SQL
            SELECT MAX(auto_expire_date) auto_expire_date  FROM  orders o
            INNER JOIN encounter e ON e.encounter_id = o.encounter_id AND e.program_id = 1
            INNER JOIN drug_order t On t.order_id = o.order_id
            INNER JOIN drug d ON d.drug_id  = t.drug_inventory_id
            INNER JOIN concept_set s ON s.concept_id = d.concept_id AND s.concept_set  = 1085
            INNER JOIN person p ON p.person_id = e.patient_id
            WHERE o.voided = 0 AND DATE(o.start_date) = DATE('#{max_date}')
            AND p.person_id = #{patient_id} GROUP BY e.patient_id;
          SQL

          auto_expire_date = auto_expire["auto_expire_date"].to_date rescue nil
          return auto_expire_date unless auto_expire_date.blank?

          dispensed_date = order_date["start_date"].to_date
          return next_appointment_date patient_id, dispensed_date
        end

        def next_appointment_date(patient_id, start_date)
          order_date =  ActiveRecord::Base.connection.select_one <<-SQL
          SELECT value_datetime  FROM obs
          WHERE person_id = #{patient_id} AND DATE(obs_datetime) = DATE('#{start_date}')
          AND voided = 0 AND concept_id  = 5096  GROUP BY person_id;
          SQL

          auto_expire_date = order_date['value_datetime'].to_date rescue nil
          return auto_expire_date unless auto_expire_date.blank?
          return nil
        end

        def auto_expire_date_start_date_gap(start_date, auto_expire_date)
          return if auto_expire_date.blank?

          cal_days = ActiveRecord::Base.connection.select_one <<~SQL
            SELECT TIMESTAMPDIFF(day, DATE('#{auto_expire_date}'), DATE('#{start_date}')) days;
          SQL

          return cal_days['days'].to_i
        end

      end




    end
  end
end
