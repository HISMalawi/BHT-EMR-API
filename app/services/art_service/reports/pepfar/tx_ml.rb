module ARTService
  module Reports
    module Pepfar

      class TxMl
        def initialize(start_date:, end_date:)
          @start_date = start_date.to_date.strftime('%Y-%m-%d 00:00:00')
          @end_date = end_date.to_date.strftime('%Y-%m-%d 23:59:59')
        end

        def data
          return tx_ml
        end


        private

        def tx_ml
          data  = {}
          patients  = get_potential_tx_ml_clients
          patient_ids  = []

          (patients || []).each do |pat|
            patient_ids << pat['patient_id']
          end

          return [] if patient_ids.blank?

          filtered_patients = ActiveRecord::Base.connection.select_all <<EOF
          SELECT
            o.patient_id, birthdate, gender, o.start_date, o.auto_expire_date, d.name, t.quantity ,
            TIMESTAMPDIFF(day, DATE(o.auto_expire_date), DATE('#{@end_date}')) days_gone,
            pepfar_patient_outcome(p.person_id, date('#{@end_date}')) outcome,
            cohort_disaggregated_age_group(p.birthdate, DATE('#{@end_date}')) age_group
          FROM person p
          INNER JOIN orders o ON o.patient_id = p.person_id
          INNER JOIN drug_order t ON o.order_id = t.order_id
          INNER JOIN drug d ON d.drug_id = t.drug_inventory_id
          INNER JOIN concept_set s ON s.concept_id = d.concept_id AND s.concept_set=1085
          WHERE o.voided = 0 AND. o.start_date <= '#{@start_date}'
          AND (o.auto_expire_date BETWEEN '#{@start_date}' AND '#{@end_date}')
          AND o.patient_id IN(#{patient_ids.join(',')})
          AND o.patient_id NOT IN(
              SELECT patient_id FROM orders o2
              INNER JOIN drug_order t2 ON t2.order_id = o2.order_id
              INNER JOIN drug d2 ON d2.drug_id = t2.drug_inventory_id
              INNER JOIN concept_set s1 ON s1.concept_id = d2.concept_id AND s1.concept_set = 1085
              WHERE o2.start_date BETWEEN '#{@start_date}' AND '#{@end_date}'
          )AND t.quantity > 0 GROUP BY o.patient_id, d.name, date(o.auto_expire_date)
          ORDER BY days_gone;
EOF


          (filtered_patients || []).each do |pat|
            outcome = pat['outcome']
            days_gone = pat['days_gone'].to_i

            next if outcome == 'On antiretrovirals'
            next unless days_gone > 27

            patient_id = pat['patient_id'].to_i
            auto_expire_date =  pat['auto_expire_date'].to_date
            start_date = pat['start_date'].to_date
            gender = pat['gender'].first.upcase rescue 'Unknown'
            age_group = pat['age_group']

            if data[age_group].blank?
              data[age_group]= {}
              data[age_group][gender] = [0, 0, 0, 0, 0]
            elsif data[age_group][gender].blank?
              data[age_group][gender] = [0, 0, 0, 0, 0]
            end

            case outcome
              when 'Defaulted'
                data[age_group][gender][0] +=  1
              when 'Patient died'
                data[age_group][gender][1] +=  1
              when 'Stopped'
                data[age_group][gender][2] +=  1
              when 'Patient transferred out'
                data[age_group][gender][3] +=  1
              else
                data[age_group][gender][4] +=  1

            end
          end

          return data
        end

        def get_potential_tx_ml_clients
          return ActiveRecord::Base.connection.select_all <<EOF
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
                and (DATE(`s`.`start_date`) <= '#{@start_date.to_date.strftime("%Y-%m-%d 23:59:59")}')
                and pepfar_patient_outcome(p.patient_id, DATE('#{@start_date}')) = 'On antiretrovirals'
          group by `p`.`patient_id`
          HAVING date_enrolled IS NOT NULL;
EOF

        end


      end




    end
  end
end
