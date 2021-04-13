
module ARTService
  module Reports
    module Pepfar

      class TbPrev
        def initialize(start_date:, end_date:)
          @completion_start_date = start_date.to_date.strftime('%Y-%m-%d 00:00:00')
          @completion_end_date = end_date.to_date.strftime('%Y-%m-%d 23:59:59')
        end

        def report
          return data
        end

        private

        def data
          meds  = tb_med_dispensations
          return {} if meds.blank?

          patient_ids = meds.map{|m| m["patient_id"].to_i}.uniq
          hiv_program_clients = on_art_in_reporting_period(patient_ids)
          return if hiv_program_clients.blank?
          clients_in_hiv_program = {}

          hiv_program_clients.each do |e|
            clients_in_hiv_program[e["patient_id"].to_i] = e
          end

          clients = {}

          total_ipt_dispensed = {}
          initiation_start_date = (@completion_start_date.to_date - 6.month).to_date

          meds.each do |m|
            patient_id = m["patient_id"].to_i
            inh_start_date = min_inh_start_date(patient_id)
            next unless (inh_start_date.to_date >= initiation_start_date.to_date &&
              inh_start_date.to_date < @completion_start_date.to_date)
            p = clients_in_hiv_program[patient_id]
            next if p.blank?

            earliest_start_date  = (p["earliest_start_date"].to_date rescue p["date_enrolled"].to_date)

            quantity = m["quantity"].to_f
            clients[patient_id] = {
              date_enrolled: p["date_enrolled"].to_date,
              earliest_start_date: earliest_start_date,
              gender: (p["gender"].upcase.first rescue 'Unknown'),
              birthdate: (p["birthdate"].to_date rescue "Unknow"),
              age_group: p["age_group"],
              course_completed: false,
              client: new_client(earliest_start_date, inh_start_date),
              quantity: 0
            } if clients[patient_id].blank?

            clients[patient_id][:quantity] += quantity

            if clients[patient_id][:quantity] >= 168
              clients[patient_id][:course_completed] = true
            end

          end

          return clients
        end

        def min_inh_start_date(patient_id)
          start_date =  ActiveRecord::Base.connection.select_one <<-SQL
            SELECT
                DATE(MIN(o.start_date)) date
            FROM person p
            INNER JOIN orders o ON o.patient_id = p.person_id
            INNER JOIN drug_order t ON o.order_id = t.order_id
            INNER JOIN drug d ON d.drug_id = t.drug_inventory_id
            INNER JOIN encounter e ON e.patient_id = o.patient_id AND e.program_id = 1
            WHERE o.voided = 0 AND o.patient_id = #{patient_id}
            AND d.concept_id = 656 AND t.quantity > 0;
          SQL

          return start_date["date"].to_date
        end

        def new_client(earliest_start_date, min_date)
          med_start_date = min_date.to_date
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
               cohort_disaggregated_age_group(pe.birthdate, DATE('#{@completion_end_date}')) age_group
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
          initiation_start_date = (@completion_start_date.to_date - 6.month).strftime('%Y-%m-%d 00:00:00')

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
            BETWEEN '#{initiation_start_date}' AND '#{@completion_end_date}')
            AND d.concept_id = 656 AND t.quantity > 0
            GROUP BY o.patient_id, t.drug_inventory_id, DATE(o.start_date)
            ORDER BY o.patient_id;
          SQL
        end


















      end




    end
  end
end
