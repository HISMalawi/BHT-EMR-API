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
              p.person_id, birthdate, gender,
              cohort_disaggregated_age_group(p.birthdate, DATE('#{@end_date}')) age_group
            FROM person p
            WHERE p.voided = 0
            AND pepfar_patient_outcome(p.person_id, DATE('#{@end_date}')) = 'On antiretrovirals'
            AND p.person_id IN(#{patient_ids.join(',')})
            ORDER BY p.person_id ASC;
          SQL


          (filtered_patients || []).each do |pat|
            patient_id = pat['person_id'].to_i
            age_group = pat['age_group']
            gender = pat['gender'].upcase.first rescue 'Unknown'


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
                and (pepfar_patient_outcome(p.patient_id, DATE('#{(@end_date.to_date - 31.day)}')) = 'Defaulted'
                or pepfar_patient_outcome(p.patient_id, DATE('#{(@start_date.to_date - 1.day)}')) = 'Defaulted')
          group by `p`.`patient_id`
          HAVING date_enrolled IS NOT NULL AND DATE(date_enrolled) < DATE('#{@start_date}');
          SQL

        end


      end




    end
  end
end
