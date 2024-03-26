# frozen_string_literal: true

module ArtService
  module Reports
    module Pepfar
      class TbPrev
        def initialize(start_date:, end_date:)
          @completion_start_date = start_date.to_date.strftime('%Y-%m-%d 00:00:00')
          @completion_end_date = end_date.to_date.strftime('%Y-%m-%d 23:59:59')
        end

        def report
          data
        end

        private

        def data
          meds = tb_med_dispensations
          return {} if meds.blank?

          patient_ids = meds.map { |m| m['patient_id'].to_i }.uniq
          hiv_program_clients = on_art_in_reporting_period(patient_ids)
          return if hiv_program_clients.blank?

          clients_in_hiv_program = {}

          hiv_program_clients.each do |e|
            clients_in_hiv_program[e['patient_id'].to_i] = e
          end

          clients = {}
          initiation_start_date = (@completion_start_date.to_date - 6.month).to_date

          meds.each do |m|
            patient_id = m['patient_id'].to_i
            inh_start_date = min_inh_start_date(patient_id)
            next unless inh_start_date.to_date >= initiation_start_date.to_date &&
                        inh_start_date.to_date < @completion_start_date.to_date

            p = clients_in_hiv_program[patient_id]
            next if p.blank?

            earliest_start_date = begin
              p['earliest_start_date'].to_date
            rescue StandardError
              p['date_enrolled'].to_date
            end

            quantity = m['quantity'].to_f
            if clients[patient_id].blank?
              clients[patient_id] = {
                date_enrolled: p['date_enrolled'].to_date,
                earliest_start_date:,
                gender: begin
                  p['gender'].upcase.first
                rescue StandardError
                  'Unknown'
                end,
                birthdate: begin
                  p['birthdate'].to_date
                rescue StandardError
                  'Unknow'
                end,
                age_group: p['age_group'],
                course_completed: false,
                client: new_client(earliest_start_date, inh_start_date),
                quantity: 0
              }
            end

            clients[patient_id][:quantity] += quantity

            clients[patient_id][:course_completed] = true if clients[patient_id][:quantity] >= 168
          end

          clients
        end

        def min_inh_start_date(patient_id)
          start_date = ActiveRecord::Base.connection.select_one <<-SQL
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

          start_date['date'].to_date
        end

        def new_client(earliest_start_date, min_date)
          med_start_date = min_date.to_date
          med_end_date = (earliest_start_date.to_date + 90.day).to_date

          return 'New on ART' if med_start_date >= earliest_start_date.to_date && med_start_date < med_end_date

          'Previously on ART'
        end

        def client_outcome(patient_id)
          outcome_string = ActiveRecord::Base.connection.select_one <<-SQL
            SELECT pepfar_patient_outcome(#{patient_id}, DATE('#{@end_date}')) outcome;
          SQL

          outcome_string['outcome']
        end

        def on_art_in_reporting_period(patient_ids)
          ActiveRecord::Base.connection.select_all <<-SQL
            select
              `p`.`patient_id` AS `patient_id`, pe.birthdate, pe.gender,
               cast(patient_date_enrolled(`p`.`patient_id`) as date) AS `date_enrolled`,
               date_antiretrovirals_started(`p`.`patient_id`, min(`s`.`start_date`)) AS `earliest_start_date`,
               disaggregated_age_group(pe.birthdate, DATE('#{@completion_end_date}')) age_group
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
                  and `p`.patient_id IN(#{patient_ids.join(',')}))
            group by `p`.`patient_id`
            HAVING date_enrolled IS NOT NULL;
          SQL
        end

        def tb_med_dispensations
          initiation_start_date = (@completion_start_date.to_date - 6.month).strftime('%Y-%m-%d 00:00:00')

          ActiveRecord::Base.connection.select_all <<-SQL
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
