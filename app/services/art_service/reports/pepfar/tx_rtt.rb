module ARTService
  module Reports
    module Pepfar
      class TxRTT
        attr_reader :start_date, :end_date

        def initialize(start_date:, end_date:)
          @start_date = ActiveRecord::Base.connection.quote(start_date)
          @end_date = ActiveRecord::Base.connection.quote(end_date)
        end

        def data
          tx_rtt.each_with_object({}) do |patient, report|
            age_group = report[patient['age_group']] || { 'M' => [], 'F' => [], 'Unknown' => [] }
            age_group[patient['gender']&.first&.upcase || 'Unknown'] << patient['patient_id']

            report[patient['age_group']] = age_group
          end
        end

        private

        def tx_rtt
          ActiveRecord::Base.connection.select_all <<~SQL
            SELECT patient_program.patient_id,
                 cohort_disaggregated_age_group(person.birthdate, #{end_date}) AS age_group,
                 person.gender,
                 IF(
                   patient_state_at_start_of_quarter.state = 6,
                   'Treatment stopped',
                   IF(
                     patient_state_at_start_of_quarter.state = 12,
                     'Defaulted',
                     pepfar_patient_outcome(patient_program.patient_id, #{start_date})
                   )
                 ) AS initial_outcome,
                 IF(
                   patients_with_orders_at_end_of_quarter.patient_id IS NOT NULL,
                   'On antiretrovirals',
                   IF(
                     current_pepfar_defaulter(patient_program.patient_id, #{end_date}) = 0,
                     'On antiretrovirals',
                     'Defaulted'
                   )
                 ) AS final_outcome
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
              SELECT DISTINCT encounter.patient_id
              FROM encounter
              INNER JOIN orders
                ON orders.encounter_id = encounter.encounter_id
                AND orders.start_date BETWEEN DATE(#{start_date}) AND DATE(#{end_date})
                AND orders.voided = 0
              INNER JOIN drug_order
                ON drug_order.order_id = orders.order_id
                AND drug_order.quantity > 0
                AND drug_order.drug_inventory_id IN (SELECT DISTINCT drug_id FROM arv_drug)
              WHERE encounter.voided = 0
                AND encounter.program_id = 1
                AND encounter.encounter_datetime BETWEEN DATE(#{start_date}) AND DATE(#{end_date})
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
            INNER JOIN patient_state AS patient_state_at_end_of_quarter
              ON patient_state_at_end_of_quarter.patient_program_id = patient_program.patient_program_id
              AND patient_state_at_end_of_quarter.date_created = date_of_last_patient_state_before_quarter.date_created
              AND patient_state_at_end_of_quarter.state = 7
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
                AND orders.start_date BETWEEN DATE(#{start_date}) AND DATE(#{end_date})
                AND orders.auto_expire_date >= (DATE(#{end_date}) - INTERVAL 30 DAY)
              INNER JOIN drug_order
                ON drug_order.order_id = orders.order_id
                AND drug_order.quantity > 0
                AND drug_order.drug_inventory_id IN (SELECT DISTINCT drug_id FROM arv_drug)
              WHERE encounter.program_id = 1
                AND encounter.encounter_datetime BETWEEN DATE(#{start_date}) AND DATE(#{end_date})
                AND encounter.voided = 0
            ) AS patients_with_orders_at_end_of_quarter
              ON patients_with_orders_at_end_of_quarter.patient_id = patient_program.patient_id
            WHERE patient_program.program_id = 1
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
                WHERE ((orders.start_date BETWEEN (DATE(#{start_date}) - INTERVAL 30 DAY) AND DATE(#{start_date}))
                       OR (orders.auto_expire_date BETWEEN (DATE(#{start_date}) - INTERVAL 30 DAY) AND DATE(#{start_date})))
                  AND orders.voided = 0
              )
            GROUP BY patient_program.patient_id
            HAVING initial_outcome IN ('Defaulted', 'Treatment stopped')
               AND final_outcome = 'On antiretrovirals'
          SQL
        end
      end
    end
  end
end
