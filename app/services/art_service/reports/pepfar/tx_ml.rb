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
          tx_curr = get_potential_tx_ml_clients
          tx_new  = get_new_potential_tx_ml_clients
          patient_ids  = []
          earliest_start_dates = {}

          (tx_curr || []).each do |pat|
            patient_id = pat['patient_id'].to_i
            patient_ids << patient_id
            earliest_start_dates[patient_id] = pat['earliest_start_date'].to_date rescue pat['date_enrolled'].to_date
          end

          (tx_new || []).each do |pat|
            patient_id = pat['patient_id'].to_i
            patient_ids << patient_id
            patient_ids = patient_ids.uniq
            earliest_start_dates[patient_id] = pat['earliest_start_date'].to_date rescue pat['date_enrolled'].to_date
          end

          (tx_new || []).each do |pat|
            patient_ids << pat['patient_id']
            patient_ids = patient_ids.uniq
          end

          return [] if patient_ids.blank?


          filtered_patients = ActiveRecord::Base.connection.select_all <<EOF
          SELECT
            p.person_id patient_id, birthdate, gender,
            pepfar_patient_outcome(p.person_id, date('#{@end_date}')) outcome,
            cohort_disaggregated_age_group(p.birthdate, DATE('#{@end_date}')) age_group
          FROM person p WHERE p.person_id IN(#{patient_ids.join(",")}) GROUP BY p.person_id;
EOF

          (filtered_patients || []).each do |pat|
            outcome = pat['outcome']
            next if outcome == 'On antiretrovirals'

            patient_id = pat['patient_id'].to_i
            gender = pat['gender'].first.upcase rescue 'Unknown'
            age_group = pat['age_group']

            if data[age_group].blank?
              data[age_group]= {}
              data[age_group][gender] = [[], [], [], [], [], []]
            elsif data[age_group][gender].blank?
              data[age_group][gender] = [[], [], [], [], [], []]
            end

            case outcome
              when 'Defaulted'
                new_def = new_defaulter(patient_id, earliest_start_dates[patient_id])
                (new_def == true  ? data[age_group][gender][0] << patient_id : data[age_group][gender][1] << patient_id)
              when 'Patient died'
                data[age_group][gender][2] << patient_id
              when /Stopped/i
                data[age_group][gender][3] << patient_id
              when 'Patient transferred out'
                data[age_group][gender][4] << patient_id
              else
                data[age_group][gender][5] << patient_id

            end
          end

          return data
        end

        def get_potential_tx_ml_clients
          return ActiveRecord::Base.connection.select_all <<EOF
          select
            `p`.`patient_id` AS `patient_id`, pe.birthdate, pe.gender,
             cast(patient_date_enrolled(`p`.`patient_id`) as date) AS `date_enrolled`,
             date_antiretrovirals_started(`p`.`patient_id`, min(`s`.`start_date`)) AS `earliest_start_date`
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
                and (DATE(`s`.`start_date`) < '#{@start_date.to_date}')
                and pepfar_patient_outcome(p.patient_id, DATE('#{@start_date.to_date - 1.day}')) = 'On antiretrovirals'
          group by `p`.`patient_id`
          HAVING date_enrolled IS NOT NULL AND DATE(date_enrolled) < '#{@start_date.to_date}';
EOF

        end

        def get_new_potential_tx_ml_clients
          return ActiveRecord::Base.connection.select_all <<EOF
          SELECT
            `p`.`patient_id` AS `patient_id`, pe.birthdate, pe.gender,
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
                AND (DATE(`s`.`start_date`)
                BETWEEN '#{@start_date.to_date.strftime("%Y-%m-%d 00:00:00")}' AND '#{@end_date}')
          GROUP BY `p`.`patient_id`
          HAVING date_enrolled IS NOT NULL
          AND date_enrolled BETWEEN '#{@start_date.to_date}' AND '#{@end_date.to_date}';
EOF

        end

        def new_defaulter(patient_id, earliest_start_date)

          defaulter_date = ActiveRecord::Base.connection.select_one <<~SQL
          SELECT current_pepfar_defaulter_date(#{patient_id}, '#{@end_date}') def_date;
          SQL

          defaulter_date  = defaulter_date["def_date"].to_date rescue @end_date.to_date
          days_gone = ActiveRecord::Base.connection.select_one <<~SQL
          SELECT TIMESTAMPDIFF(day, DATE('#{earliest_start_date}'), DATE('#{defaulter_date}')) days;
          SQL

          new_def  = (days_gone["days"].to_i > 90 ? false : true)
          return new_def
        end

      end




    end
  end
end
