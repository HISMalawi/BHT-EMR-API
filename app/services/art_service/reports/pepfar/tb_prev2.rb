# frozen_string_literal: true

module ARTService
  module Reports
    module Pepfar
      ##
      # Patients who started TPT just before the start of the current
      # and have finished within the current reporting period.
      class TbPrev2
        attr_reader :start_date, :end_date

        include Utils

        def initialize(start_date:, end_date:, **_kwargs)
          @start_date = ActiveRecord::Base.connection.quote(start_date)
          @end_date = ActiveRecord::Base.connection.quote(end_date)
        end

        def find_report
          report = init_report

          load_patients_into_report(report, patients_on_tpt('Pyridoxine'), '6H') do |patient|
            # 6H has a constant dosage of 1 pill per day
            patient['total_pills_taken'].to_i >= FULL_6H_COURSE_PILLS
          end

          load_patients_into_report(report, patients_on_tpt('Rifapentine'), '3HP') do |patient|
            # 3HP daily dosages vary by patient weight can't use easily use pills
            # to determine course completion
            patient['total_days_on_medication'].days >= FULL_3HP_COURSE_DAYS
          end

          report
        end

        private

        FULL_6H_COURSE_PILLS = 168
        FULL_3HP_COURSE_DAYS = (28.days - 1.day) + (56.days - 1.day) # 82 Days
        # NOTE: Arrived at 82 days above from how 3HP is prescribed. 1st time prescription
        #       is 1 month (28 days) then 2 months (56 days). And we assume that patients
        #       start taking medication the very same they are given thus we subtract 1.

        def init_report
          pepfar_age_groups.each_with_object({}) do |age_group, report|
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

        def patients_on_tpt(tpt_concept_name)
          tpt_concept_name = ActiveRecord::Base.connection.quote(tpt_concept_name)

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
              AND concept_name.name = #{tpt_concept_name}
            INNER JOIN drug_order
              ON drug_order.order_id = orders.order_id
              AND drug_order.quantity > 0
            INNER JOIN (
              /* People (re-)initiated in the 6 months period prior to reporting period. */
              SELECT DISTINCT encounter.patient_id
              FROM encounter
              INNER JOIN orders
                ON orders.encounter_id = encounter.encounter_id
                AND orders.order_type_id IN (SELECT order_type_id FROM order_type WHERE name = 'Drug order')
                AND orders.concept_id IN (SELECT concept_id FROM concept_name WHERE name = #{tpt_concept_name} AND voided = 0)
                AND orders.start_date >= DATE(#{start_date}) - INTERVAL 6 MONTH
                AND orders.start_date < DATE(#{start_date})
                AND orders.voided = 0
              INNER JOIN drug_order
                ON drug_order.order_id = orders.order_id
                AND drug_order.quantity > 0
              INNER JOIN concept_name
                ON concept_name.concept_id = orders.concept_id
                AND concept_name.name = #{tpt_concept_name}
                AND concept_name.voided = 0
              WHERE encounter.program_id IN (SELECT program_id FROM program WHERE name = 'HIV Program')
                AND encounter.encounter_type IN (SELECT encounter_type_id FROM encounter_type WHERE name = 'Treatment')
                AND encounter.encounter_datetime >= DATE(#{start_date}) - INTERVAL 6 MONTH
                AND encounter.encounter_datetime < DATE(#{start_date})
                AND encounter.voided = 0
                AND encounter.patient_id NOT IN (
                  /* People who had a dispensation prior to the 3 to 9 months before start of reporting period.
                     Continuing medication after a 9 months break is considered a restart hence such patients
                     are classified as new on TPT.
                   */
                  SELECT DISTINCT encounter.patient_id
                  FROM encounter
                  INNER JOIN orders
                    ON orders.encounter_id = encounter.encounter_id
                    AND orders.concept_id IN (SELECT concept_id FROM concept_name WHERE name = #{tpt_concept_name} AND voided = 0)
                    AND orders.order_type_id IN (SELECT order_type_id FROM order_type WHERE name = 'Drug order')
                    AND orders.start_date < DATE(#{start_date}) - INTERVAL 6 MONTH
                    AND orders.start_date >= DATE(#{start_date}) - INTERVAL 15 MONTH
                    AND orders.voided = 0
                  INNER JOIN drug_order
                    ON drug_order.order_id = orders.order_id
                    AND drug_order.quantity > 0
                  WHERE encounter.program_id IN (SELECT program_id FROM program WHERE name = 'HIV Program')
                    AND encounter.encounter_type IN (SELECT encounter_type_id FROM encounter_type WHERE name = 'Treatment')
                    AND encounter.encounter_datetime < DATE(#{start_date}) - INTERVAL 6 MONTH
                    AND encounter.voided = 0
                )
            ) AS tpt_initiates
              ON tpt_initiates.patient_id = patient_program.patient_id
            WHERE person.voided = 0
            GROUP BY person.person_id
          SQL
        end
      end
    end
  end
end
