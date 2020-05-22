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
          patients  = get_potential_tx_rtt_clients
          patient_ids  = []

          (patients || []).each do |pat|
            patient_ids << pat['patient_id']
          end

          return [] if patient_ids.blank?

          filtered_patients = ActiveRecord::Base.connection.select_all <<-SQL
            SELECT
              o.patient_id, birthdate, gender, o.start_date,
              MAX(o.start_date) start_date, t.quantity,
              cohort_disaggregated_age_group(p.birthdate, DATE('#{@end_date}')) age_group
            FROM person p
            INNER JOIN orders o ON o.patient_id = p.person_id
            INNER JOIN drug_order t ON o.order_id = t.order_id
            INNER JOIN drug d ON d.drug_id = t.drug_inventory_id
            INNER JOIN concept_set s ON s.concept_id = d.concept_id AND s.concept_set=1085
            WHERE o.voided = 0 AND (o.start_date BETWEEN '#{@start_date}' AND '#{@end_date}')
            AND o.patient_id IN(#{patient_ids.join(',')})
            AND t.quantity > 0 GROUP BY o.patient_id
            ORDER BY o.start_date DESC, o.patient_id ASC;
          SQL


          (filtered_patients || []).each do |pat|
            patient_id = pat['patient_id'].to_i
            start_date = pat['start_date'].to_date
            age_group = pat['age_group']
            gender = pat['gender'].upcase.first rescue 'Unknown'
            max_prev_auto_expire_date = prev_dispensation_date(patient_id, start_date)
            next if max_prev_auto_expire_date.blank?

            calculate_days = ActiveRecord::Base.connection.select_one <<-SQL
              SELECT TIMESTAMPDIFF(day, DATE('#{max_prev_auto_expire_date}'), DATE('#{start_date}')) days;
            SQL

            days_gone = calculate_days['days'].to_i
            next  if days_gone < 14

            if data[age_group].blank?
              data[age_group]= {}
              data[age_group][gender] = [[], [], []]
            elsif data[age_group][gender].blank?
              data[age_group][gender] = [[], [], []]
            end

            if days_gone < 28
              data[age_group][gender][0] << patient_id
            elsif days_gone >= 28 && days_gone < 60
              data[age_group][gender][1] << patient_id
            else
              data[age_group][gender][2] << patient_id
            end


          end

          return data
        end

        def prev_dispensation_date(patient_id, start_date)
          filtered_data = ActiveRecord::Base.connection.select_one <<EOF
          SELECT
            MAX(o.auto_expire_date) auto_expire_date
          FROM person p
          INNER JOIN orders o ON o.patient_id = p.person_id
          INNER JOIN drug_order t ON o.order_id = t.order_id
          INNER JOIN drug d ON d.drug_id = t.drug_inventory_id
          INNER JOIN concept_set s ON s.concept_id = d.concept_id AND s.concept_set=1085
          WHERE o.voided = 0 AND o.start_date <= DATE('#{start_date}')
          AND o.patient_id = #{patient_id}
          AND t.quantity > 0 ORDER BY o.auto_expire_date DESC;
EOF

          return nil if filtered_data.blank?
          return filtered_data['auto_expire_date'].to_date rescue nil
        end

        def get_potential_tx_rtt_clients
          return ActiveRecord::Base.connection.select_all <<-SQL
          select
            `p`.`patient_id` AS `patient_id`, pe.birthdate, pe.gender,
             cast(patient_date_enrolled(`p`.`patient_id`) as date) AS `date_enrolled`
          from
            ((`patient_program` `p`
            left join `person` `pe` ON ((`pe`.`person_id` = `p`.`patient_id`))
            left join `patient_state` `s` ON ((`p`.`patient_program_id` = `s`.`patient_program_id`)))
            left join `person` ON ((`person`.`person_id` = `p`.`patient_id`)))
          where
            ((`p`.`voided` = 0)
                and (`s`.`voided` = 0)
                and (`p`.`program_id` = 1)
                and (`s`.`state` = 7))
                /*and (DATE(`s`.`start_date`) BETWEEN '#{@start_date}' AND '#{@end_date}')*/
                and pepfar_patient_outcome(p.patient_id, DATE('#{@end_date}')) = 'On antiretrovirals'
          group by `p`.`patient_id`
          HAVING date_enrolled IS NOT NULL;
          SQL

        end


      end




    end
  end
end
