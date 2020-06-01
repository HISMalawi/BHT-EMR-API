
module ARTService
  module Reports
    module Pepfar

      class TbPrev
        def initialize(start_date:, end_date:)
          @start_date = start_date.to_date.strftime('%Y-%m-%d 00:00:00')
          @end_date = end_date.to_date.strftime('%Y-%m-%d 23:59:59')
        end

        def report
          return data
        end

        private

        def data
          meds  = tb_med_dispensations
          return {} if meds.blank?

          patient_ids = meds.map{|m| m["patient_id"].to_i}.uniq
          total_clients = on_art_in_reporting_period(patient_ids)
          return if total_clients.blank?
          clients = {}

          total_ipt_dispensed = Hash.new(0)
          clients_in_report  = []
          clients_med_dispensation_dates = {}

          meds.each do |m|
            patient_id = m["patient_id"].to_i
            quantity = m["quantity"].to_f
            total_ipt_dispensed[patient_id] += quantity
            clients_med_dispensation_dates[patient_id] = [] if clients_med_dispensation_dates[patient_id].blank?
            clients_med_dispensation_dates[patient_id]  << m["start_date"].to_date

            if total_ipt_dispensed[patient_id] >= 168
              clients_in_report << patient_id
            end

          end

          total_clients.map do |p|
            patient_id = p["patient_id"].to_i
            next unless clients_in_report.include?(patient_id)
            earliest_start_date  = (p["earliest_start_date"].to_date rescue p["date_enrolled"].to_date)
            clients[patient_id] = {
              date_enrolled: p["date_enrolled"].to_date,
              earliest_start_date: earliest_start_date,
              gender: (p["gender"].upcase.first rescue 'Unknown'),
              birthdate: (p["birthdate"].to_date rescue "Unknow"),
              age_group: p["age_group"],
              outcome: client_outcome(patient_id),
              client: new_client(earliest_start_date, clients_med_dispensation_dates[patient_id])
            }
          end

          return clients
        end

        def new_client(earliest_start_date, dates)
          med_start_date = dates.sort.first.to_date
          med_end_date = (earliest_start_date.to_date  +  90.day).to_date

          if med_start_date >= earliest_start_date.to_date && med_start_date < med_end_date
            return "New on ART"
          else
            return "Previously on ART"
          end
        end

        def client_outcome(patient_id)
          outcome_string = ActiveRecord::Base.connection.select_one <<-SQL
            SELECT pepfar_patient_outcome(#{patient_id}, DATE('#{@end_date}')) outcome;
          SQL

          return outcome_string["outcome"]
        end

        def on_art_in_reporting_period(patient_ids)
          return ActiveRecord::Base.connection.select_all <<-SQL
            select
              `p`.`patient_id` AS `patient_id`, pe.birthdate, pe.gender,
               cast(patient_date_enrolled(`p`.`patient_id`) as date) AS `date_enrolled`,
               date_antiretrovirals_started(`p`.`patient_id`, min(`s`.`start_date`)) AS `earliest_start_date`,
               cohort_disaggregated_age_group(pe.birthdate, DATE('#{@end_date}')) age_group
            from
              ((`patient_program` `p`
              left join `person` `pe` ON ((`pe`.`person_id` = `p`.`patient_id`))
              left join `patient_state` `s` ON ((`p`.`patient_program_id` = `s`.`patient_program_id`)))
              left join `person` ON ((`person`.`person_id` = `p`.`patient_id`)))
            where
              ((`p`.`voided` = 0)
                  and (`s`.`voided` = 0)
                  and (`p`.`program_id` = 1)
                  and (`s`.`state` = 7)
                  and `p`.patient_id IN(#{patient_ids.join(",")}))
            group by `p`.`patient_id`
            HAVING date_enrolled IS NOT NULL;
          SQL

        end

        def tb_med_dispensations
          date_six_months_ago = (@start_date.to_date - 6.months).strftime('%Y-%m-%d 00:00:00')
          date_six_months_ago_end = (@start_date.to_date - 1.day).to_date
          date_six_months_ago_end = date_six_months_ago_end.strftime('%Y-%m-%d 23:59:59')

          return ActiveRecord::Base.connection.select_all <<-SQL
            SELECT
                o.patient_id, t.drug_inventory_id, t.quantity,
                o.start_date, o.auto_expire_date
            FROM person p
            INNER JOIN orders o ON o.patient_id = p.person_id
            INNER JOIN drug_order t ON o.order_id = t.order_id
            INNER JOIN drug d ON d.drug_id = t.drug_inventory_id
            INNER JOIN encounter e ON e.patient_id = o.patient_id AND e.program_id = 1
            WHERE o.voided = 0 AND (o.start_date
            BETWEEN '#{date_six_months_ago}' AND '#{date_six_months_ago_end}')
            AND d.concept_id = 656 AND t.quantity > 0
            GROUP BY o.patient_id, t.drug_inventory_id, DATE(o.start_date)
            ORDER BY o.patient_id;
          SQL
        end


















      end




    end
  end
end
