# frozen_string_literal: true

module ARTService
  module Reports
    module Pepfar
      ## Viral Load Coverage Report
      # 1. given the start and end dates, this report will go back 12 months using the end date
      # 2. pick all clients that are due in the mentioned period
      # 3. the picked clients should also include those that are new on ART 6 months before the end date
      # 4. for the sample drawns available pick the latest sample drawn within the reporting period
      # 5. for the results pick the latest result within the reporting period
      class ViralLoadCoverage2
        attr_reader :start_date, :end_date

        include Utils

        def initialize(start_date:, end_date:, **_kwargs)
          @start_date = start_date&.to_date
          raise InvalidParameterError, 'start_date is required' unless @start_date

          @end_date = end_date&.to_date || @start_date + 12.months
          raise InvalidParameterError, "start_date can't be greater than end_date" if @start_date > @end_date
        end

        def find_report
          report = init_report
          build_report(report)
          report
        end

        def vl_maternal_status(patient_list)
          return { FP: [], FBf: [] } if patient_list.blank?

          pregnant = pregnant_women(patient_list).map { |woman| woman['person_id'].to_i }
          return { FP: pregnant, Fbf: [] } if (patient_list - pregnant).blank?

          feeding = breast_feeding(patient_list - pregnant).map { |woman| woman['person_id'].to_i }

          {
            FP: pregnant,
            FBf: feeding
          }
        end

        private

        def pregnant_women(patient_list)
          ActiveRecord::Base.connection.select_all <<~SQL
            SELECT o.person_id, o.value_coded
            FROM obs o
            INNER JOIN encounter e ON e.encounter_id = o.encounter_id AND e.voided = 0 AND e.encounter_type IN (#{encounter_types.to_sql})
            INNER JOIN person p ON e.person_id = e.patient_id AND LEFT(e.gender, 1) = 'F'
            INNER JOIN (
              SELECT person_id, MAX(obs_datetime) AS obs_datetime
              FROM obs
              INNER JOIN encounter ON encounter.encounter_id = obs.encounter_id AND encounter.encounter_type IN (#{encounter_types.to_sql}) AND encounter.voided = 0
              WHERE obs.concept_id IN (#{pregnant_concepts.to_sql})
                AND obs.obs_datetime BETWEEN DATE(#{ActiveRecord::Base.connection.quote(start_date)}) AND DATE(#{ActiveRecord::Base.connection.quote(end_date)}) + INTERVAL 1 DAY
                AND obs.voided = 0
              GROUP BY person_id
            ) AS max_obs ON max_obs.person_id = obs.person_id AND max_obs.obs_datetime = obs.obs_datetime
            WHERE o.concept_id IN (#{pregnant_concepts.to_sql})
              AND o.voided = 0
              AND o.value_coded IN (#{yes_concepts.join(',')})
              AND o.person_id IN (#{patient_list.join(',')})
            GROUP BY o.person_id
          SQL
        end

        def breast_feeding(patient_list)
          ActiveRecord::Base.connection.select_all <<~SQL
            SELECT o.person_id, o.value_coded
            FROM obs o
            INNER JOIN encounter e ON e.encounter_id = o.encounter_id AND e.voided = 0 AND e.encounter_type IN (#{encounter_types.to_sql})
            INNER JOIN person p ON e.person_id = e.patient_id AND LEFT(e.gender, 1) = 'F'
            INNER JOIN (
              SELECT person_id, MAX(obs_datetime) AS obs_datetime
              FROM obs
              INNER JOIN encounter ON encounter.encounter_id = obs.encounter_id AND encounter.encounter_type IN (#{encounter_types.to_sql}) AND encounter.voided = 0
              WHERE obs.concept_id IN (#{breast_feeding_concepts.to_sql})
                AND obs.obs_datetime BETWEEN DATE(#{ActiveRecord::Base.connection.quote(start_date)}) AND DATE(#{ActiveRecord::Base.connection.quote(end_date)}) + INTERVAL 1 DAY
                AND obs.voided = 0
              GROUP BY person_id
            ) AS max_obs ON max_obs.person_id = obs.person_id AND max_obs.obs_datetime = obs.obs_datetime
            WHERE o.concept_id IN (#{breast_feeding_concepts.to_sql})
              AND o.voided = 0
              AND o.value_coded IN (#{yes_concepts.join(',')})
              AND o.person_id IN (#{patient_list.join(',')})
            GROUP BY o.person_id
          SQL
        end

        def build_report(report)
          clients = due_for_viral_load.map { |patient| patient unless patient['due_status'].zero? }.compact
          return report if clients.blank?

          clients.each { |patient| report[patient['age_group']][:due_for_vl] << patient }
          load_patient_tests_into_report(report, clients.map { |patient| patient['patient_id'] })
        end

        def load_patient_tests_into_report(report, clients)
          find_patients_with_viral_load(clients).each do |patient|
            age_group = patient['age_group']
            reason_for_test = (patient['reason_for_test'] || 'Routine').match?(/Routine/i) ? :routine : :targeted

            report[age_group][:drawn][reason_for_test] << patient
            next unless patient['result_value']

            if patient['result_value'].casecmp?('LDL')
              report[age_group][:low_vl][reason_for_test] << patient
            elsif patient['result_value'].to_i < 1000
              report[age_group][:low_vl][reason_for_test] << patient
            else
              report[age_group][:high_vl][reason_for_test] << patient
            end
          end
        end

        ## This method prepares the response structure for the report
        def init_report
          pepfar_age_groups.each_with_object({}) do |age_group, report|
            report[age_group] = {
              due_for_vl: [],
              drawn: { routine: [], targeted: [] },
              high_vl: { routine: [], targeted: [] },
              low_vl: { routine: [], targeted: [] }
            }
          end
        end

        def due_for_viral_load
          ActiveRecord::Base.connection.select_all <<~SQL
            (#{find_patients_with_overdue_viral_load}) UNION (#{find_patients_due_for_initial_viral_load})
          SQL
        end

        def adverse_outcomes
          @adverse_outcomes ||= ActiveRecord::Base.connection.select_all(
            <<~SQL
              SELECT pws.program_workflow_state_id state
              FROM program_workflow pw
              INNER JOIN concept_name pcn ON pcn.concept_id = pw.concept_id AND pcn.concept_name_type = 'FULLY_SPECIFIED' AND pcn.voided = 0
              INNER JOIN program_workflow_state pws ON pws.program_workflow_id = pw.program_workflow_id AND pws.retired = 0
              INNER JOIN concept_name cn ON cn.concept_id = pws.concept_id AND cn.concept_name_type = 'FULLY_SPECIFIED' AND cn.voided = 0
              WHERE pw.program_id = 1 AND pw.retired = 0 AND pws.terminal = 1
            SQL
          ).map { |state| state['state'] }
        end

        ##
        # Selects patients whose last viral load should have expired before the end of the reporting period.
        #
        # Patients returned by this aren't necessarily due for viral load, they may have
        # their current milestone delayed. So extra processing on the patients is required
        # to filter out the patients with delayed milestones.
        def find_patients_with_overdue_viral_load
          # Find all patients whose last order's expires in or before the reporting period (making them due)
          # or patients whose first order comes at 6 months or greater after starting ART.
          <<~SQL
            SELECT orders.patient_id,
                   disaggregated_age_group(p.birthdate, DATE(#{ActiveRecord::Base.connection.quote(end_date)})) AS age_group,
                   p.birthdate,
                   p.gender,
                   patient_identifier.identifier AS arv_number,
                   CASE WHEN state_within_order_period.start_date < DATE(orders.start_date) + INTERVAL 12 MONTH THEN FALSE ELSE TRUE END AS due_status
            FROM orders
            INNER JOIN person p ON p.person_id = orders.patient_id
            INNER JOIN order_type
              ON order_type.order_type_id = orders.order_type_id
              AND order_type.name = 'Lab'
              AND order_type.retired = 0
            INNER JOIN concept_name
              ON concept_name.concept_id = orders.concept_id
              AND concept_name.name IN ('Blood', 'DBS (Free drop to DBS card)', 'DBS (Using capillary tube)')
              AND concept_name.voided = 0
            INNER JOIN (
              /* Get the latest order dates for each patient */
              SELECT orders.patient_id, MAX(orders.start_date) AS start_date
              FROM orders
              INNER JOIN order_type
                ON order_type.order_type_id = orders.order_type_id
                AND order_type.name = 'Lab'
                AND order_type.retired = 0
              INNER JOIN concept_name
                ON concept_name.concept_id = orders.concept_id
                AND concept_name.name IN ('Blood', 'DBS (Free drop to DBS card)', 'DBS (Using capillary tube)')
                AND concept_name.voided = 0
              WHERE orders.start_date < DATE(#{ActiveRecord::Base.connection.quote(end_date)}) - INTERVAL 12 MONTH
                AND orders.voided = 0
              GROUP BY orders.patient_id
            ) AS latest_patient_order_date
              ON latest_patient_order_date.patient_id = orders.patient_id
              AND latest_patient_order_date.start_date = orders.start_date
            LEFT JOIN(
              /* Get the current adverse outcome within the reporting period */
              SELECT pp.patient_id, ps.state, ps.start_date
              FROM patient_program pp
              INNER JOIN patient_state ps ON ps.patient_program_id = pp.patient_program_id
              INNER JOIN (
                SELECT ps.patient_program_id, MAX(ps.start_date) start_date
                  FROM patient_program pap
                  INNER JOIN patient_state ps ON ps.patient_program_id = pap.patient_program_id
                  WHERE pap.program_id = 1
                  AND ps.start_date BETWEEN DATE(#{ActiveRecord::Base.connection.quote(end_date)}) - INTERVAL 12 MONTH AND DATE(#{ActiveRecord::Base.connection.quote(end_date)})
                  GROUP BY ps.patient_program_id
              ) AS previous ON previous.patient_program_id = ps.patient_program_id AND previous.start_date = ps.start_date
              WHERE pp.program_id = 1 AND pp.voided = 0 AND ps.state IN (#{adverse_outcomes.join(',')})
            ) state_within_order_period ON state_within_order_period.patient_id = orders.patient_id
            INNER JOIN (
              SELECT pp.patient_id, ps.state, ps.start_date
              FROM patient_program pp
              INNER JOIN patient_state ps ON ps.patient_program_id = pp.patient_program_id
              INNER JOIN (
                SELECT ps.patient_program_id, MAX(ps.start_date) start_date
                  FROM patient_program pap
                  INNER JOIN patient_state ps ON ps.patient_program_id = pap.patient_program_id
                  WHERE pap.program_id = 1 AND ps.start_date <= DATE(#{ActiveRecord::Base.connection.quote(end_date)}) - INTERVAL 12 MONTH
                  GROUP BY ps.patient_program_id
              ) AS previous ON previous.patient_program_id = ps.patient_program_id AND previous.start_date = ps.start_date
              WHERE pp.program_id = 1 AND pp.voided = 0
            ) state_before_period ON state_before_period.patient_id = orders.patient_id AND state_before_period.state NOT IN (#{adverse_outcomes.join(',')})
            LEFT JOIN patient_identifier
              ON patient_identifier.patient_id = orders.patient_id
              AND patient_identifier.identifier_type IN (#{pepfar_patient_identifier_type.to_sql})
              AND patient_identifier.voided = 0
            WHERE orders.start_date < DATE(#{ActiveRecord::Base.connection.quote(end_date)}) - INTERVAL 12 MONTH
              AND orders.voided = 0
            GROUP BY orders.patient_id
          SQL
        end

        ##
        # Returns all patients that have been on ART for at least 6 months and have never had a Viral Load.
        def find_patients_due_for_initial_viral_load
          <<~SQL
            SELECT
              p.person_id AS patient_id,
              disaggregated_age_group(p.birthdate, DATE(#{ActiveRecord::Base.connection.quote(end_date)})) age_group,
              p.birthdate,
              p.gender,
              pid.identifier AS arv_number,
              CASE WHEN state_within_order_period.start_date < DATE(MIN(ps.start_date)) + INTERVAL 6 MONTH THEN FALSE ELSE TRUE END AS due_status
            FROM person p
            INNER JOIN patient_program pp ON pp.patient_id = p.person_id AND pp.program_id = #{Program.find_by_name('HIV Program').id} AND pp.voided = 0
            INNER JOIN patient_state ps ON ps.patient_program_id = pp.patient_program_id AND ps.state = 7
            LEFT JOIN(
              /* Get the current adverse outcome within the reporting period */
              SELECT pp.patient_id, ps.state, ps.start_date
              FROM patient_program pp
              INNER JOIN patient_state ps ON ps.patient_program_id = pp.patient_program_id
              INNER JOIN (
                SELECT ps.patient_program_id, MAX(ps.start_date) start_date
                  FROM patient_program pap
                  INNER JOIN patient_state ps ON ps.patient_program_id = pap.patient_program_id
                  WHERE pap.program_id = 1
                  AND ps.start_date BETWEEN DATE(#{ActiveRecord::Base.connection.quote(end_date)}) - INTERVAL 12 MONTH AND DATE(#{ActiveRecord::Base.connection.quote(end_date)})
                  GROUP BY ps.patient_program_id
              ) AS previous ON previous.patient_program_id = ps.patient_program_id AND previous.start_date = ps.start_date
              WHERE pp.program_id = 1 AND pp.voided = 0 AND ps.state IN (#{adverse_outcomes.join(',')})
            ) state_within_order_period ON state_within_order_period.patient_id = p.person_id
            INNER JOIN (
              SELECT pp.patient_id, ps.state, ps.start_date
              FROM patient_program pp
              INNER JOIN patient_state ps ON ps.patient_program_id = pp.patient_program_id
              INNER JOIN (
                SELECT ps.patient_program_id, MAX(ps.start_date) start_date
                  FROM patient_program pap
                  INNER JOIN patient_state ps ON ps.patient_program_id = pap.patient_program_id
                  WHERE pap.program_id = 1 AND ps.start_date <= DATE(#{ActiveRecord::Base.connection.quote(end_date)}) - INTERVAL 12 MONTH
                  GROUP BY ps.patient_program_id
              ) AS previous ON previous.patient_program_id = ps.patient_program_id AND previous.start_date = ps.start_date
              WHERE pp.program_id = 1 AND pp.voided = 0
            ) state_before_period ON state_before_period.patient_id = p.person_id AND state_before_period.state NOT IN (#{adverse_outcomes.join(',')})
            LEFT JOIN patient_identifier pid ON pid.patient_id = p.person_id AND pid.voided = 0 AND pid.identifier_type IN (#{pepfar_patient_identifier_type.to_sql})
            WHERE p.person_id NOT IN (
              SELECT orders.patient_id
              FROM orders
              INNER JOIN order_type ON order_type.order_type_id = orders.order_type_id AND order_type.name = 'Lab' AND order_type.retired = 0
              INNER JOIN concept_name ON concept_name.concept_id = orders.concept_id AND concept_name.name IN ('Blood', 'DBS (Free drop to DBS card)', 'DBS (Using capillary tube)') AND concept_name.voided = 0
              INNER JOIN obs ON orders.order_id = obs.order_id AND obs.voided = 0
              INNER JOIN concept_name AS cn ON cn.concept_id = obs.concept_id AND cn.name = 'Test type' AND cn.voided = 0
              INNER JOIN concept_name AS test_name ON test_name.concept_id = obs.value_coded AND test_name.name = 'HIV Viral Load' AND test_name.voided = 0
              WHERE orders.start_date <= DATE(#{ActiveRecord::Base.connection.quote(end_date)}) - INTERVAL 12 MONTH
                AND orders.voided = 0
              GROUP BY orders.patient_id
            )
            AND ps.start_date <= DATE(#{ActiveRecord::Base.connection.quote(end_date)}) - INTERVAL 6 MONTH
            AND p.voided = 0
            AND p.person_id NOT IN (#{drug_refills_and_external_consultation_list})
            GROUP BY p.person_id
          SQL
        end

        ##
        # Find all patients that are on treatment with at least one VL before end of reporting period.
        def find_patients_with_viral_load(clients)
          ActiveRecord::Base.connection.select_all <<~SQL
            SELECT orders.patient_id,
                   disaggregated_age_group(patient.birthdate,
                                                  DATE(#{ActiveRecord::Base.connection.quote(end_date)})) AS age_group,
                   patient.birthdate,
                   patient.gender,
                   patient_identifier.identifier AS arv_number,
                   orders.start_date AS order_date,
                   COALESCE(orders.discontinued_date, orders.start_date) AS sample_draw_date,
                   COALESCE(reason_for_test_value.name, reason_for_test.value_text) AS reason_for_test,
                   result.value_modifier AS result_modifier,
                   COALESCE(result.value_numeric, result.value_text) AS result_value
            FROM orders
            INNER JOIN person patient ON patient.person_id = orders.patient_id AND patient.voided = 0
            INNER JOIN order_type
              ON order_type.order_type_id = orders.order_type_id
              AND order_type.name = 'Lab'
              AND order_type.retired = 0
            INNER JOIN concept_name
              ON concept_name.concept_id = orders.concept_id
              AND concept_name.name IN ('Blood', 'DBS (Free drop to DBS card)', 'DBS (Using capillary tube)')
              AND concept_name.voided = 0
            LEFT JOIN obs AS reason_for_test
              ON reason_for_test.order_id = orders.order_id
              AND reason_for_test.concept_id IN (SELECT concept_id FROM concept_name WHERE name LIKE 'Reason for test' AND voided = 0)
              AND reason_for_test.voided = 0
            LEFT JOIN concept_name AS reason_for_test_value
              ON reason_for_test_value.concept_id = reason_for_test.value_coded
              AND reason_for_test_value.voided = 0
            LEFT JOIN obs AS result
              ON result.order_id = orders.order_id
              AND result.concept_id IN (SELECT concept_id FROM concept_name WHERE name LIKE 'HIV Viral load' AND voided = 0)
              AND result.voided = 0
              AND (result.value_text IS NOT NULL OR result.value_numeric IS NOT NULL)
            INNER JOIN (
              /* Get the latest order dates for each patient */
              SELECT orders.patient_id, MAX(orders.start_date) AS start_date
              FROM orders
              INNER JOIN order_type
                ON order_type.order_type_id = orders.order_type_id
                AND order_type.name = 'Lab'
                AND order_type.retired = 0
              INNER JOIN concept_name
                ON concept_name.concept_id = orders.concept_id
                AND concept_name.name IN ('Blood', 'DBS (Free drop to DBS card)', 'DBS (Using capillary tube)')
                AND concept_name.voided = 0
              WHERE orders.start_date < DATE(#{ActiveRecord::Base.connection.quote(end_date)}) + INTERVAL 1 DAY
                AND orders.start_date >= DATE(#{ActiveRecord::Base.connection.quote(start_date)}) - INTERVAL 12 MONTH
                AND orders.voided = 0
              GROUP BY orders.patient_id
            ) AS latest_patient_order_date
              ON latest_patient_order_date.patient_id = orders.patient_id
              AND latest_patient_order_date.start_date = orders.start_date
            LEFT JOIN patient_identifier
              ON patient_identifier.patient_id = orders.patient_id
              AND patient_identifier.identifier_type IN (#{pepfar_patient_identifier_type.to_sql})
              AND patient_identifier.voided = 0
            WHERE orders.start_date < DATE(#{ActiveRecord::Base.connection.quote(end_date)}) + INTERVAL 1 DAY
              AND orders.start_date >= DATE(#{ActiveRecord::Base.connection.quote(start_date)}) - INTERVAL 12 MONTH
              AND orders.voided = 0
              AND orders.patient_id IN (#{clients.join(',')})
            GROUP BY orders.patient_id
          SQL
        end

        # this just gives all clients who are truly external or drug refill
        # rubocop:disable Metrics/MethodLength
        # rubocop:disable Metrics/AbcSize
        def drug_refills_and_external_consultation_list
          to_remove = [0]

          type_of_patient_concept = ConceptName.find_by_name('Type of patient').concept_id
          new_patient_concept = ConceptName.find_by_name('New patient').concept_id
          drug_refill_concept = ConceptName.find_by_name('Drug refill').concept_id
          external_concept = ConceptName.find_by_name('External Consultation').concept_id
          hiv_clinic_registration_id = EncounterType.find_by_name('HIV CLINIC REGISTRATION').encounter_type_id

          ActiveRecord::Base.connection.select_all("
            SELECT p.person_id patient_id
            FROM person p
            INNER JOIN patient_program pp ON pp.patient_id = p.person_id AND pp.program_id = #{Program.find_by_name('HIV Program').id} AND pp.voided = 0
            INNER JOIN patient_state ps ON ps.patient_program_id = pp.patient_program_id AND ps.state = 7 AND ps.start_date IS NOT NULL
            LEFT JOIN encounter as hiv_registration ON hiv_registration.patient_id = p.person_id AND hiv_registration.encounter_datetime < DATE(#{ActiveRecord::Base.connection.quote(end_date)}) AND hiv_registration.encounter_type = #{hiv_clinic_registration_id} AND hiv_registration.voided = 0
            LEFT JOIN (SELECT * FROM obs WHERE concept_id = #{type_of_patient_concept} AND voided = 0 AND value_coded = #{new_patient_concept} AND obs_datetime < DATE(#{ActiveRecord::Base.connection.quote(end_date)}) + INTERVAL 1 DAY) AS new_patient ON p.person_id = new_patient.person_id
            LEFT JOIN (SELECT * FROM obs WHERE concept_id = #{type_of_patient_concept} AND voided = 0 AND value_coded = #{drug_refill_concept} AND obs_datetime < DATE(#{ActiveRecord::Base.connection.quote(end_date)}) + INTERVAL 1 DAY) AS refill ON p.person_id = refill.person_id
            LEFT JOIN (SELECT * FROM obs WHERE concept_id = #{type_of_patient_concept} AND voided = 0 AND value_coded = #{external_concept} AND obs_datetime < DATE(#{ActiveRecord::Base.connection.quote(end_date)}) + INTERVAL 1 DAY) AS external ON p.person_id = external.person_id
            WHERE (refill.value_coded IS NOT NULL OR external.value_coded IS NOT NULL)
            AND NOT (hiv_registration.encounter_id IS NOT NULL OR new_patient.value_coded IS NOT NULL)
            GROUP BY p.person_id
            ORDER BY hiv_registration.encounter_datetime DESC, refill.obs_datetime DESC, external.obs_datetime DESC;").each do |record|
            to_remove << record['patient_id'].to_i
          end
          to_remove.join(',')
        end
        # rubocop:enable Metrics/MethodLength
        # rubocop:enable Metrics/AbcSize

        def yes_concepts
          @yes_concepts ||= ConceptName.where(name: 'Yes').select(:concept_id).map { |record| record['concept_id'].to_i }
        end

        def pregnant_concepts
          @pregnant_concepts ||= ConceptName.where(name: ['Is patient pregnant?', 'patient pregnant'])
                                            .select(:concept_id)
        end

        def breast_feeding_concepts
          @breast_feeding_concepts ||= ConceptName.where(name: ['Breast feeding?', 'Breast feeding', 'Breastfeeding'])
                                                  .select(:concept_id)
        end

        def encounter_types
          @encounter_types ||= EncounterType.where(name: ['HIV CLINIC CONSULTATION', 'HIV STAGING'])
                                            .select(:encounter_type_id)
        end
      end
    end
  end
end
