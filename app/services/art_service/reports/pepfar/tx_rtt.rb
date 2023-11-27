# frozen_string_literal: true
module ARTService
  module Reports
    module Pepfar
      class TxRTT
        attr_reader :start_date, :end_date

        include CommonSqlQueryUtils
        include Utils

        def initialize(start_date:, end_date:, **kwargs)
          @start_date = ActiveRecord::Base.connection.quote(start_date.to_date.beginning_of_day.strftime('%Y-%m-%d %H:%M:%S'))
          @end_date = ActiveRecord::Base.connection.quote(end_date.to_date.end_of_day.strftime('%Y-%m-%d %H:%M:%S'))
          @occupation = kwargs[:occupation]
        end

        def find_report
          process_report
        end

        def data
          process_report
        rescue StandardError => e
          Rails.logger.error "Error running TX_RTT Report: #{e}"
          Rails.logger.error e.backtrace.join("\n")
          raise e
        end

        private

        GENDER = %w[M F].freeze

        def init_report
          pepfar_age_groups.each_with_object({}) do |age_group, age_group_report|
            age_group_report[age_group] = GENDER.each_with_object({}) do |gender, gender_report|
              gender_report[gender] = indicators
            end
          end
        end

        def process_report
          report = init_report
          process_data report
          flatten_the_report report
        end

        def process_data(report)
          tx_rtt.each do |row|
            age_group = row['age_group']
            gender = row['gender']
            months = row['months']
            patient_id = row['patient_id']
            cd4_cat = row['cd4_count_group']

            next unless GENDER.include?(gender)
            next unless pepfar_age_groups.include?(age_group)

            cat = report[age_group][gender]
            process_months(cat, months, patient_id)
            process_cd4(cat, months, patient_id, cd4_cat)
          end
        end

        def process_months(report, months, patient_id)
          report[:returned_less_than_3_months] << patient_id if months.blank?
          report[:returned_less_than_3_months] << patient_id if months < 3
          report[:returned_greater_than_3_months_and_less_than_6_months] << patient_id if months >= 3 && months < 6
          report[:returned_greater_than_or_equal_to_6_months] << patient_id if months >= 6
        end

        def process_cd4(report, months, patient_id, cd4_cat)
          if cd4_cat == 'unknown_cd4_count' && months <= 2
            report[:not_eligible_for_cd4] << patient_id
            return
          end

          report[cd4_cat.to_sym] << patient_id
        end

        def indicators
          {
            'cd4_less_than_200': [],
            'cd4_greater_than_or_equal_to_200': [],
            'unknown_cd4_count': [],
            'not_eligible_for_cd4': [],
            'returned_less_than_3_months': [],
            'returned_greater_than_3_months_and_less_than_6_months': [],
            'returned_greater_than_or_equal_to_6_months': []
          }
        end

        def process_age_group_report(age_group, gender, age_group_report)
          {
            age_group: age_group,
            gender: gender,
            cd4_less_than_200: age_group_report[:cd4_less_than_200],
            cd4_greater_than_or_equal_to_200: age_group_report[:cd4_greater_than_or_equal_to_200],
            unknown_cd4_count: age_group_report[:unknown_cd4_count],
            not_eligible_for_cd4: age_group_report[:not_eligible_for_cd4],
            returned_less_than_3_months: age_group_report[:returned_less_than_3_months],
            returned_greater_than_3_months_and_less_than_6_months: age_group_report[:returned_greater_than_3_months_and_less_than_6_months],
            returned_greater_than_or_equal_to_6_months: age_group_report[:returned_greater_than_or_equal_to_6_months]
          }
        end

        def flatten_the_report(report)
          result = []
          report.each do |age_group, age_group_report|
            result << process_age_group_report(age_group, 'M', age_group_report['M'])
            result << process_age_group_report(age_group, 'F', age_group_report['F'])
          end
          sorted_results = result.sort_by do |item|
            gender_score = item[:gender] == 'Female' ? 0 : 1
            age_group_score = pepfar_age_groups.index(item[:age_group])
            [gender_score, age_group_score]
          end
          # sort by gender, start all females and push all males to the end
          sorted_results.sort_by { |h| [h[:gender] == 'F' ? 0 : 1] }
        end

        def tx_rtt
          ActiveRecord::Base.connection.select_all <<~SQL
              SELECT patient_program.patient_id,
                disaggregated_age_group(person.birthdate, #{end_date}) AS age_group,
                person.gender,
                IF(
                  patient_state_at_start_of_quarter.state = 6, 'Treatment stopped',
                  IF(
                    patient_state_at_start_of_quarter.state = 12, 'Defaulted',
                    pepfar_patient_outcome(patient_program.patient_id, (DATE(#{start_date}) - INTERVAL 1 DAY) )
                  )
                 ) AS initial_outcome,
                 IF(
                  patient_state_at_start_of_quarter.state = 6,
                  patient_state_at_start_of_quarter.start_date,
                  IF(
                    patient_state_at_start_of_quarter.state = 12,
                    patient_state_at_start_of_quarter.start_date,
                    current_pepfar_defaulter_date(patient_program.patient_id, (DATE(#{start_date}) - INTERVAL 1 DAY) ))) AS initial_outcome_date,
                  IF(
                    patients_with_orders_at_end_of_quarter.patient_id IS NOT NULL,  'On antiretrovirals',
                   IF(
                      current_pepfar_defaulter(patient_program.patient_id, #{end_date}) = 0,
                     'On antiretrovirals','Defaulted'
                  )
                 ) AS final_outcome,
                 TIMESTAMPDIFF(MONTH, IF(
                    patient_state_at_start_of_quarter.state = 6,
                    patient_state_at_start_of_quarter.start_date,
                    IF(
                      patient_state_at_start_of_quarter.state = 12,
                  patient_state_at_start_of_quarter.start_date,
                  current_pepfar_defaulter_date(patient_program.patient_id, (DATE(#{start_date}) - INTERVAL 1 DAY) ))), patients_who_received_art_in_quarter.start_date) AS months,
                CASE
                    WHEN cd4_result.value_numeric < 200 THEN 'cd4_less_than_200'
                    WHEN cd4_result.value_numeric = 200 AND cd4_result.value_modifier = '=' THEN 'cd4_greater_than_or_equal_to_200'
                    WHEN cd4_result.value_numeric = 200 AND cd4_result.value_modifier = '<' THEN 'cd4_less_than_200'
                    WHEN cd4_result.value_numeric = 200 AND cd4_result.value_modifier = '>' THEN 'cd4_greater_than_or_equal_to_200'
                    WHEN cd4_result.value_numeric > 200 THEN 'cd4_greater_than_or_equal_to_200'
                    ELSE 'unknown_cd4_count'
                END cd4_count_group
            FROM patient_program
            INNER JOIN person ON person.person_id = patient_program.patient_id
            /* Select patients that were on treatment before start of reporting period */
            INNER JOIN patient_state AS patient_ever_on_treatment
              ON patient_ever_on_treatment.patient_program_id = patient_program.patient_program_id
              AND patient_ever_on_treatment.state = 7
              AND patient_ever_on_treatment.start_date < DATE(#{start_date})
              AND patient_ever_on_treatment.voided = 0
            /* Get patient's state at the start of the quarter. */
            INNER JOIN (
              SELECT patient_program_id, MAX(patient_state.date_created) AS date_created
              FROM patient_state
              INNER JOIN patient_program USING (patient_program_id)
              WHERE patient_state.voided = 0
                AND patient_program.voided = 0
                AND patient_program.program_id = 1
                AND patient_state.start_date < DATE(#{start_date}) + INTERVAL 1 DAY
              GROUP BY patient_program_id
            ) AS date_of_last_patient_state_before_quarter
              ON date_of_last_patient_state_before_quarter.patient_program_id = patient_program.patient_program_id
            LEFT JOIN patient_state AS patient_state_at_start_of_quarter
              ON patient_state_at_start_of_quarter.patient_program_id = date_of_last_patient_state_before_quarter.patient_program_id
              AND patient_state_at_start_of_quarter.date_created = date_of_last_patient_state_before_quarter.date_created
              AND patient_state_at_start_of_quarter.state IN (6, 12) /* 2: TO, 6: Tx Stopped, 12: Defaulted */
            /* Select patients who received ART within the reporting period. */
            INNER JOIN (
              SELECT DISTINCT encounter.patient_id, orders.start_date
              FROM encounter
              INNER JOIN orders
                ON orders.encounter_id = encounter.encounter_id
                AND DATE(orders.start_date) BETWEEN DATE(#{start_date}) AND DATE(#{end_date})
                AND orders.voided = 0
              INNER JOIN drug_order
                ON drug_order.order_id = orders.order_id
                AND drug_order.quantity > 0
                AND drug_order.drug_inventory_id IN (SELECT DISTINCT drug_id FROM arv_drug)
              WHERE encounter.voided = 0
                AND encounter.program_id = 1
                AND DATE(encounter.encounter_datetime) BETWEEN DATE(#{start_date}) AND DATE(#{end_date})
            ) AS patients_who_received_art_in_quarter
              ON patients_who_received_art_in_quarter.patient_id = patient_program.patient_id
            /* Ensure that patients are on ART at the end of the quarter */
            INNER JOIN (
              SELECT patient_program_id, MAX(patient_state.date_created) AS date_created
              FROM patient_state
              INNER JOIN patient_program USING (patient_program_id)
              WHERE patient_state.voided = 0
                AND patient_program.voided = 0
                AND patient_program.program_id = 1
                AND patient_state.start_date < DATE(#{end_date}) + INTERVAL 1 DAY
              GROUP BY patient_program_id
            ) AS date_of_last_patient_state_in_quarter
              ON date_of_last_patient_state_in_quarter.patient_program_id = patient_program.patient_program_id

              /*Not sure why Walter had this section in but I believe its not neccessary*/
              /*INNER JOIN patient_state AS patient_state_at_end_of_quarter
              ON patient_state_at_end_of_quarter.patient_program_id = patient_program.patient_program_id
              AND patient_state_at_end_of_quarter.date_created = date_of_last_patient_state_before_quarter.date_created
              AND patient_state_at_end_of_quarter.state = 7*/

            /* Select patient who had orders in the last 30 days of the reporting period.
               This is to be used as a quick filter for patients who are definitely
               'On ART' by the end of the reporting period. The rest will be filtered by
               the current_defaulter function. */
            LEFT JOIN (
              SELECT DISTINCT encounter.patient_id
              FROM encounter
              INNER JOIN orders
                ON orders.encounter_id = encounter.encounter_id
                AND orders.voided = 0
                AND DATE(orders.start_date) BETWEEN DATE(#{start_date}) AND DATE(#{end_date})
                AND DATE(orders.auto_expire_date) >= (DATE(#{end_date}) - INTERVAL 30 DAY)
              INNER JOIN drug_order
                ON drug_order.order_id = orders.order_id
                AND drug_order.quantity > 0
                AND drug_order.drug_inventory_id IN (SELECT DISTINCT drug_id FROM arv_drug)
              WHERE encounter.program_id = 1
                AND DATE(encounter.encounter_datetime) BETWEEN DATE(#{start_date}) AND DATE(#{end_date})
                AND encounter.voided = 0
            ) AS patients_with_orders_at_end_of_quarter
              ON patients_with_orders_at_end_of_quarter.patient_id = patient_program.patient_id
            LEFT JOIN (
                SELECT max(o.obs_datetime) AS obs_datetime, o.person_id
                FROM obs o
                INNER JOIN concept_name cn ON cn.concept_id = o.concept_id AND cn.name = 'CD4 count'
                WHERE o.concept_id = #{concept_name('CD4 count').concept_id} AND o.voided = 0
                AND o.obs_datetime <= #{end_date} AND o.obs_datetime >= #{start_date}
                GROUP BY o.person_id
            ) current_cd4 ON current_cd4.person_id = patient_program.patient_id
            LEFT JOIN obs cd4_result ON cd4_result.person_id = patient_program.patient_id AND cd4_result.concept_id = #{concept_name('CD4 count').concept_id} AND cd4_result.voided = 0 AND cd4_result.obs_datetime = current_cd4.obs_datetime
            LEFT JOIN (#{current_occupation_query}) a ON a.person_id = patient_program.patient_id
            WHERE patient_program.program_id = 1 #{%w[Military Civilian].include?(@occupation) ? 'AND' : ''} #{occupation_filter(occupation: @occupation, field_name: 'value', table_name: 'a', include_clause: false)}
              /* Ensure that the patients retrieved, did not receive ART within 28 days
                 before the start of the reporting period */
              AND patient_program.patient_id NOT IN (
                SELECT DISTINCT orders.patient_id
                FROM orders
                INNER JOIN drug_order USING (order_id)
                INNER JOIN arv_drug ON arv_drug.drug_id = drug_inventory_id
                INNER JOIN patient_program
                  ON patient_program.patient_id = orders.patient_id
                  AND patient_program.program_id = 1
                WHERE ((DATE(orders.start_date )BETWEEN (DATE(#{start_date}) - INTERVAL 30 DAY) AND DATE(#{start_date}))
                       OR (DATE(orders.auto_expire_date) BETWEEN (DATE(#{start_date}) - INTERVAL 30 DAY) AND DATE(#{start_date})))
                  AND orders.voided = 0
              )
            GROUP BY patient_program.patient_id
            HAVING initial_outcome IN ('Defaulted', 'Treatment stopped')
               AND final_outcome = 'On antiretrovirals';
          SQL
        end
      end
    end
  end
end
