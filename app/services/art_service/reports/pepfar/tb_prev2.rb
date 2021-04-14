# frozen_string_literal: true

module ARTService
  module Reports
    module Pepfar
      ##
      # Patients who started TPT just before the start of the current
      # and have finished within the current reporting period.
      class TbPrev2
        attr_reader :start_date, :end_date

        def initialize(start_date:, end_date:, **_kwargs)
          @start_date = ActiveRecord::Base.connection.quote(start_date)
          @end_date = ActiveRecord::Base.connection.quote(end_date)
        end

        def find_report
          report = init_report

          load_patients_into_report(report, patients_on_6h, '6H') do |patient|
            # 6H has a constant dosage of 1 pill per day
            patient['total_pills_taken'].to_i >= FULL_6H_COURSE_PILLS
          end

          load_patients_into_report(report, patients_on_3hp, '3HP') do |patient|
            # 3HP daily dosages vary by patient weight can't use easily use pills
            # to determine course completion
            patient['total_days_on_medication'].to_i >= FULL_3HP_COURSE_MONTHS
          end

          report
        end

        private

        FULL_6H_COURSE_PILLS = 168
        FULL_3HP_COURSE_MONTHS = 28 * 3 # Months in days

        AGE_GROUPS = [
          'Unknown',
          '0-5 months',
          '6-11 months',
          '12-23 months',
          '2-4 years',
          '5-9 years',
          '10-14 years',
          '15-17 years',
          '18-19 years',
          '20-24 years',
          '25-29 years',
          '30-34 years',
          '35-39 years',
          '40-44 years',
          '45-49 years',
          '50 plus years'
        ].freeze

        def init_report
          AGE_GROUPS.each_with_object({}) do |age_group, report|
            report[age_group] = %w[M F Unknown].each_with_object({}) do |gender, gender_sub_report|
              gender_sub_report[gender] = %w[6H 3HP].each_with_object({}) do |tpt, tpt_sub_report|
                tpt_sub_report[tpt] = {
                  started_new_on_art: [],
                  started_previously_on_art: [],
                  completed_new_on_art: [],
                  completed_previously_on_art: []
                }
              end
            end
          end
        end

        def load_patients_into_report(report, patients, tpt, &patient_has_completed_tpt)
          patients.each do |patient|
            age_group = patient['age_group']
            gender = patient['gender']&.first&.upcase || 'Unknown'
            tpt_states = find_patient_tpt_state(patient, &patient_has_completed_tpt)

            tpt_states.each do |tpt_state|
              report[age_group][gender][tpt][tpt_state] << patient
            end
          end
        end

        def find_patient_tpt_state(patient, &patient_has_completed_tpt)
          if patient_has_completed_tpt[patient]
            return %i[started_new_on_art completed_new_on_art] if patient_new_on_art?(patient)

            return %i[started_previously_on_art completed_previously_on_art]
          end

          return %i[started_new_on_art] if patient_new_on_art?(patient)

          %i[started_previously_on_art]
        end

        def patient_new_on_art?(patient)
          tpt_initiation_date = patient['tpt_initiation_date'].to_date
          art_start_date = patient['art_start_date'].to_date

          (tpt_initiation_date >= art_start_date) && (tpt_initiation_date < art_start_date + 90.days)
        end

        def patients_on_6h
          ActiveRecord::Base.connection.select_all <<~SQL
            SELECT person.person_id AS patient_id,
                   patient_identifier.identifier AS arv_number,
                   DATE(MIN(orders.start_date)) AS tpt_initiation_date,
                   date_antiretrovirals_started(person.person_id, MIN(patient_state.start_date)) AS art_start_date,
                   SUM(drug_order.quantity) AS total_pills_taken,
                   SUM(DATEDIFF(orders.auto_expire_date, orders.start_date)) AS total_days_on_medication,
                   person.gender,
                   person.birthdate,
                   cohort_disaggregated_age_group(person.birthdate, DATE(#{end_date})) AS age_group
            FROM person
            LEFT JOIN patient_identifier
              ON patient_identifier.patient_id = person.person_id
              AND patient_identifier.voided = 0
              AND patient_identifier.identifier_type IN (SELECT patient_identifier_type_id FROM patient_identifier_type WHERE name = 'ARV Number')
            INNER JOIN patient_program
              ON patient_program.patient_id = person.person_id
              AND patient_program.program_id IN (SELECT program_id FROM program WHERE name = 'HIV Program')
              AND patient_program.voided = 0
            INNER JOIN patient_state
              ON patient_state.patient_program_id = patient_program.patient_program_id
              AND patient_state.state = 7 /* State: 7 == On antiretrovirals */
              AND patient_state.start_date < DATE(#{end_date})
              AND patient_state.voided = 0
            INNER JOIN encounter AS prescription_encounter
              ON prescription_encounter.patient_id = patient_program.patient_id
              AND prescription_encounter.program_id IN (SELECT program_id FROM program WHERE name = 'HIV Program')
              AND prescription_encounter.encounter_type IN (SELECT encounter_type_id FROM encounter_type WHERE name = 'Treatment')
              AND prescription_encounter.encounter_datetime >= DATE(#{start_date}) - INTERVAL 6 MONTH
              AND prescription_encounter.encounter_datetime < DATE(#{end_date}) + INTERVAL 1 DAY
              AND prescription_encounter.voided = 0
            INNER JOIN orders
              ON orders.encounter_id = prescription_encounter.encounter_id
              AND orders.order_type_id IN (SELECT order_type_id FROM order_type WHERE name = 'Drug order')
              AND orders.start_date >= DATE(#{start_date}) - INTERVAL 6 MONTH
              AND orders.start_date < DATE(#{end_date}) + INTERVAL 1 DAY
              AND orders.voided = 0
            INNER JOIN concept_name
              ON concept_name.concept_id = orders.concept_id
              AND concept_name.name = 'Pyridoxine'
            INNER JOIN drug_order
              ON drug_order.order_id = orders.order_id
              AND drug_order.quantity > 0
            WHERE person.voided = 0
              AND person.person_id IN (
                /* People who have a dispensation in the 6 months prior to the current reporting period */
                SELECT DISTINCT patient_program.patient_id
                FROM patient_program
                INNER JOIN encounter AS prescription_encounter
                  ON prescription_encounter.patient_id = patient_program.patient_id
                  AND prescription_encounter.program_id IN (SELECT program_id FROM program WHERE name = 'HIV Program')
                  AND prescription_encounter.encounter_type IN (SELECT encounter_type_id FROM encounter_type WHERE name = 'Treatment')
                  AND prescription_encounter.encounter_datetime >= DATE(#{start_date}) - INTERVAL 6 MONTH
                  AND prescription_encounter.encounter_datetime < DATE(#{end_date}) + INTERVAL 1 DAY
                  AND prescription_encounter.voided = 0
                INNER JOIN orders
                  ON orders.encounter_id = prescription_encounter.encounter_id
                  AND orders.order_type_id IN (SELECT order_type_id FROM order_type WHERE name = 'Drug order')
                  AND orders.start_date >= DATE(#{start_date}) - INTERVAL 6 MONTH
                  AND orders.start_date < DATE(#{start_date})
                  AND orders.voided = 0
                INNER JOIN drug_order
                  ON drug_order.order_id = orders.order_id
                  AND drug_order.quantity > 0
                  AND drug_order.drug_inventory_id IN (
                    SELECT DISTINCT drug_id
                    FROM drug
                    INNER JOIN concept_name
                      ON concept_name.concept_id = drug.concept_id
                      AND concept_name.name = 'Pyridoxine'
                  )
                WHERE patient_program.program_id IN (SELECT program_id FROM program WHERE name = 'HIV Program')
                  AND patient_program.voided = 0
              )
              AND person.person_id NOT IN (
                /* People who had a dispensation within a period of 9 months prior to the 6 months
                   before start of the current reporting period. Patients who break medication
                   for 9 months then restart are considered new on TPT (ie re-initiates). */
                SELECT DISTINCT patient_program.patient_id
                FROM patient_program
                INNER JOIN encounter AS prescription_encounter
                  ON prescription_encounter.patient_id = patient_program.patient_id
                  AND prescription_encounter.program_id IN (SELECT program_id FROM program WHERE name = 'HIV Program')
                  AND prescription_encounter.encounter_type IN (SELECT encounter_type_id FROM encounter_type WHERE name = 'Treatment')
                  AND prescription_encounter.encounter_datetime < DATE(#{start_date}) - INTERVAL 6 MONTH
                  AND prescription_encounter.voided = 0
                INNER JOIN orders
                  ON orders.encounter_id = prescription_encounter.encounter_id
                  AND orders.order_type_id IN (SELECT order_type_id FROM order_type WHERE name = 'Drug order')
                  AND orders.start_date < DATE(#{start_date}) - INTERVAL 6 MONTH
                  AND orders.start_date >= DATE(#{start_date}) - INTERVAL 15 MONTH  /* 6 + 9 Months */
                  AND orders.voided = 0
                INNER JOIN drug_order
                  ON drug_order.order_id = orders.order_id
                  AND drug_order.quantity > 0
                  AND drug_order.drug_inventory_id IN (
                    SELECT DISTINCT drug_id
                    FROM drug
                    INNER JOIN concept_name
                      ON concept_name.concept_id = drug.concept_id
                      AND concept_name.name = 'Pyridoxine'
                  )
                WHERE patient_program.program_id IN (SELECT program_id FROM program WHERE name = 'HIV Program')
                  AND patient_program.voided = 0
              )
              AND patient_program.patient_id NOT IN (
                SELECT person_id FROM obs
                WHERE concept_id IN (
                  SELECT concept_id FROM concept_name WHERE name LIKE 'Type of patient'
                ) AND value_coded IN (
                  SELECT concept_id FROM concept_name WHERE name LIKE 'External Consultation'
                ) AND voided = 0 AND (obs_datetime < DATE(#{end_date}) + INTERVAL 1 DAY)
                GROUP BY person_id
              )
            GROUP BY person.person_id
          SQL
        end

        def patients_on_3hp
          ActiveRecord::Base.connection.select_all <<~SQL
            SELECT person.person_id AS patient_id,
                   patient_identifier.identifier AS arv_number,
                   DATE(MIN(orders.start_date)) AS tpt_initiation_date,
                   date_antiretrovirals_started(person.person_id, MIN(patient_state.start_date)) AS art_start_date,
                   SUM(drug_order.quantity) AS total_pills_taken,
                   SUM(DATEDIFF(orders.auto_expire_date, orders.start_date)) AS total_days_on_medication,
                   person.gender,
                   person.birthdate,
                   cohort_disaggregated_age_group(person.birthdate, DATE(#{end_date})) AS age_group
            FROM person
            LEFT JOIN patient_identifier
              ON patient_identifier.patient_id = person.person_id
              AND patient_identifier.voided = 0
              AND patient_identifier.identifier_type IN (SELECT patient_identifier_type_id FROM patient_identifier_type WHERE name = 'ARV Number')
            INNER JOIN patient_program
              ON patient_program.patient_id = person.person_id
              AND patient_program.program_id IN (SELECT program_id FROM program WHERE name = 'HIV Program')
              AND patient_program.voided = 0
            INNER JOIN patient_state
              ON patient_state.patient_program_id = patient_program.patient_program_id
              AND patient_state.state = 7 /* State: 7 == On antiretrovirals */
              AND patient_state.start_date < DATE(#{end_date})
              AND patient_state.voided = 0
            INNER JOIN encounter AS prescription_encounter
              ON prescription_encounter.patient_id = patient_program.patient_id
              AND prescription_encounter.program_id IN (SELECT program_id FROM program WHERE name = 'HIV Program')
              AND prescription_encounter.encounter_type IN (SELECT encounter_type_id FROM encounter_type WHERE name = 'Treatment')
              AND prescription_encounter.encounter_datetime >= DATE(#{start_date}) - INTERVAL 3 MONTH
              AND prescription_encounter.encounter_datetime < DATE(#{end_date}) + INTERVAL 1 DAY
              AND prescription_encounter.voided = 0
            INNER JOIN orders
              ON orders.encounter_id = prescription_encounter.encounter_id
              AND orders.order_type_id IN (SELECT order_type_id FROM order_type WHERE name = 'Drug order')
              AND orders.start_date >= DATE(#{start_date}) - INTERVAL 3 MONTH
              AND orders.start_date < DATE(#{end_date}) + INTERVAL 1 DAY
              AND orders.voided = 0
            INNER JOIN concept_name
              ON concept_name.concept_id = orders.concept_id
              AND concept_name.name = 'Rifapentine'
            INNER JOIN drug_order
              ON drug_order.order_id = orders.order_id
              AND drug_order.quantity > 0
            WHERE person.voided = 0
              AND person.person_id IN (
                /* People who had a dispensation in the 3 months prior to start of reporting period */
                SELECT DISTINCT patient_program.patient_id
                FROM patient_program
                INNER JOIN encounter AS prescription_encounter
                  ON prescription_encounter.patient_id = patient_program.patient_id
                  AND prescription_encounter.program_id IN (SELECT program_id FROM program WHERE name = 'HIV Program')
                  AND prescription_encounter.encounter_type IN (SELECT encounter_type_id FROM encounter_type WHERE name = 'Treatment')
                  AND prescription_encounter.encounter_datetime >= DATE(#{start_date}) - INTERVAL 3 MONTH
                  AND prescription_encounter.encounter_datetime < DATE(#{start_date})
                  AND prescription_encounter.voided = 0
                INNER JOIN orders
                  ON orders.encounter_id = prescription_encounter.encounter_id
                  AND orders.order_type_id IN (SELECT order_type_id FROM order_type WHERE name = 'Drug order')
                  AND orders.start_date >= DATE(#{start_date}) - INTERVAL 3 MONTH
                  AND orders.start_date < DATE(#{end_date})
                  AND orders.voided = 0
                INNER JOIN drug_order
                  ON drug_order.order_id = orders.order_id
                  AND drug_order.quantity > 0
                  AND drug_order.drug_inventory_id IN (
                    SELECT DISTINCT drug_id
                    FROM drug
                    INNER JOIN concept_name
                      ON concept_name.concept_id = drug.concept_id
                      AND concept_name.name = 'Rifapentine'
                  )
                WHERE patient_program.program_id IN (SELECT program_id FROM program WHERE name = 'HIV Program')
                  AND patient_program.voided = 0
              ) AND person.person_id NOT IN (
                /* People who had a dispensation prior to the 3 to 9 months before start of reporting period.
                   Continuing medication after a 9 months break is considered a restart hence such patients
                   are classified as new on TPT.
                 */
                SELECT DISTINCT patient_program.patient_id
                FROM patient_program
                INNER JOIN encounter AS prescription_encounter
                  ON prescription_encounter.patient_id = patient_program.patient_id
                  AND prescription_encounter.program_id IN (SELECT program_id FROM program WHERE name = 'HIV Program')
                  AND prescription_encounter.encounter_type IN (SELECT encounter_type_id FROM encounter_type WHERE name = 'Treatment')
                  AND prescription_encounter.encounter_datetime < DATE(#{start_date}) - INTERVAL 3 MONTH
                  AND prescription_encounter.voided = 0
                INNER JOIN orders
                  ON orders.encounter_id = prescription_encounter.encounter_id
                  AND orders.order_type_id IN (SELECT order_type_id FROM order_type WHERE name = 'Drug order')
                  AND orders.start_date < DATE(#{start_date}) - INTERVAL 3 MONTH
                  AND orders.start_date >= DATE(#{start_date}) - INTERVAL 12 MONTH
                  AND orders.voided = 0
                INNER JOIN drug_order
                  ON drug_order.order_id = orders.order_id
                  AND drug_order.quantity > 0
                  AND drug_order.drug_inventory_id IN (
                    SELECT DISTINCT drug_id
                    FROM drug
                    INNER JOIN concept_name
                      ON concept_name.concept_id = drug.concept_id
                      AND concept_name.name = 'Rifapentine'
                  )
                WHERE patient_program.program_id IN (SELECT program_id FROM program WHERE name = 'HIV Program')
                  AND patient_program.voided = 0
              )
            GROUP BY person.person_id
          SQL
        end
      end
    end
  end
end
