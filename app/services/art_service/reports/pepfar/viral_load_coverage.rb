# frozen_string_literal: true

module ARTService
  module Reports
    module Pepfar
      class ViralLoadCoverage
        attr_reader :start_date, :end_date

        include Utils

        def initialize(**params)
          @start_date = params[:start_date]&.to_date
          raise InvalidParameterError, 'start_date is required' unless @start_date

          @end_date = params[:end_date]&.to_date || @start_date + 12.months
          raise InvalidParameterError, "start_date can't be greater than end_date" if @start_date > @end_date

          @tx_curr_definition = params.fetch(:tx_curr_definition, 'pepfar')&.downcase
          unless %w[moh pepfar].include?(@tx_curr_definition)
            raise InvalidParameterError, "tx_curr_definition can only moh or pepfar not #{@tx_curr_definition}"
          end

          @rebuild_outcomes = params.fetch(:rebuild_outcomes, 'true')&.casecmp?('true')
          @type = params.fetch(:application, 'poc')
        end

        def find_report
          report = init_report

          case @type
          when /poc/i then build_poc_report(report)
          when /emastercard/i then build_emastercard_report(report)
          else raise InvalidParameterError, "Report type must be one of [poc, emastercard] not #{@type}"
          end

          report
        end

        def vl_maternal_status(patient_list)
          pregnant = pregnant_women(patient_list).map { |woman| woman['person_id'].to_i }
          feeding = breast_feeding(patient_list - pregnant).map { |woman| woman['person_id'].to_i }

          {
            FP: pregnant,
            FBf: feeding
          }
        end

        private

        def pregnant_women(patient_list)
          encounter_types = EncounterType.where(name: ['HIV CLINIC CONSULTATION', 'HIV STAGING'])
                                           .select(:encounter_type_id)

          pregnant_concepts = ConceptName.where(name: ['Is patient pregnant?', 'patient pregnant'])
                                           .select(:concept_id)

          ActiveRecord::Base.connection.select_all <<~SQL
            SELECT obs.person_id,obs.value_coded
            FROM obs obs
            INNER JOIN encounter enc
              ON enc.encounter_id = obs.encounter_id
              AND enc.voided = 0
              AND enc.encounter_type IN (#{encounter_types.to_sql})
            INNER JOIN temp_earliest_start_date e
              ON e.patient_id = enc.patient_id
              AND LEFT(e.gender, 1) = 'F'
            INNER JOIN temp_patient_outcomes
              ON temp_patient_outcomes.patient_id = e.patient_id
              AND temp_patient_outcomes.cum_outcome = 'On antiretrovirals'
            INNER JOIN (
              SELECT person_id, MAX(obs_datetime) AS obs_datetime
              FROM obs
              INNER JOIN encounter
                ON encounter.encounter_id = obs.encounter_id
                AND encounter.encounter_type IN (#{encounter_types.to_sql})
                AND encounter.voided = 0
              WHERE concept_id IN (#{pregnant_concepts.to_sql})
                AND obs_datetime BETWEEN DATE('#{@start_date}') AND DATE('#{@end_date}') + INTERVAL 1 DAY
                AND obs.voided = 0
              GROUP BY person_id
            ) AS max_obs
              ON max_obs.person_id = obs.person_id
              AND max_obs.obs_datetime = obs.obs_datetime
            WHERE obs.concept_id IN (#{pregnant_concepts.to_sql})
              AND obs.voided = 0
              AND obs.person_id IN (#{patient_list.join(',')})
            GROUP BY obs.person_id
            HAVING obs.value_coded = 1065
            ORDER BY obs.obs_datetime DESC;
          SQL
        end

        def breast_feeding(patient_list)
          encounter_types = EncounterType.where(name: ['HIV CLINIC CONSULTATION', 'HIV STAGING'])
                            .select(:encounter_type_id)

          breastfeeding_concepts = ConceptName.where(name: ['Breast feeding?', 'Breast feeding', 'Breastfeeding'])
                                .select(:concept_id)

          ActiveRecord::Base.connection.select_all <<~SQL
            SELECT obs.person_id,obs.value_coded
            FROM obs
            INNER JOIN encounter enc
              ON enc.encounter_id = obs.encounter_id
              AND enc.voided = 0
              AND enc.encounter_type IN (#{encounter_types.to_sql})
            INNER JOIN temp_earliest_start_date e
              ON e.patient_id = enc.patient_id
              AND LEFT(e.gender, 1) = 'F'
            INNER JOIN temp_patient_outcomes
              ON temp_patient_outcomes.patient_id = e.patient_id
              AND temp_patient_outcomes.cum_outcome = 'On antiretrovirals'
            INNER JOIN (
              SELECT person_id, MAX(obs_datetime) AS obs_datetime
              FROM obs
              INNER JOIN encounter
              ON encounter.encounter_id = obs.encounter_id
              AND encounter.encounter_type IN (#{encounter_types.to_sql})
              AND encounter.voided = 0
              WHERE person_id IN (SELECT patient_id FROM temp_patient_outcomes WHERE cum_outcome = 'On antiretrovirals')
              AND concept_id IN (#{breastfeeding_concepts.to_sql})
              AND obs.voided = 0
              AND obs_datetime < DATE('#{end_date}') + INTERVAL 1 DAY
              GROUP BY person_id
            ) AS max_obs
              ON max_obs.person_id = obs.person_id
              AND max_obs.obs_datetime = obs.obs_datetime
            WHERE obs.person_id = e.patient_id
            AND obs.person_id IN (#{patient_list.join(',')})
            AND obs.obs_datetime BETWEEN DATE(#{@start_date}) AND DATE(#{@end_date})
            AND obs.concept_id IN (#{breastfeeding_concepts.to_sql})
            AND obs.voided = 0
            GROUP BY obs.person_id
            HAVING obs.value_coded = 1065
            ORDER BY obs.obs_datetime DESC;
          SQL
        end

        def build_poc_report(report)
          find_patients_alive_and_on_art.each { |patient| report[patient['age_group']][:tx_curr] << patient }
          find_patients_due_for_initial_viral_load.each { |patient| report[patient['age_group']][:due_for_vl] << patient }
          find_patients_with_overdue_viral_load.each { |patient| report[patient['age_group']][:due_for_vl] << patient }
          load_patient_tests_into_report(report)
        end

        def build_emastercard_report(report)
          find_patients_alive_and_on_art.each { |patient| report[patient['age_group']][:tx_curr] << patient }
          load_emastercard_results_into_report(report)
        end

        def init_report
          pepfar_age_groups.each_with_object({}) do |age_group, report|
            report[age_group] = {
              tx_curr: [],
              due_for_vl: [],
              drawn: { routine: [], targeted: [] },
              high_vl: { routine: [], targeted: [] },
              low_vl: { routine: [], targeted: [] }
            }
          end
        end

        def load_patient_tests_into_report(report)
          find_patients_with_viral_load.each do |patient|
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

        def load_emastercard_results_into_report(report)
          find_emastercard_patient_results.each do |patient|
            if patient['result_value'] < 1000
              report[patient['age_group']][:low_vl][:routine] << patient
            else
              report[patient['age_group']][:high_vl][:routine] << patient
            end
          end
        end

        def find_patients_alive_and_on_art
          patients = PatientsAliveAndOnTreatment
                     .new(start_date: start_date, end_date: end_date, outcomes_definition: @tx_curr_definition, rebuild_outcomes: @rebuild_outcomes)
                     .query
          pepfar_patient_drilldown_information(patients, end_date).map do |patient|
            {
              'patient_id' => patient.patient_id,
              'arv_number' => patient.arv_number,
              'age_group' => patient.age_group,
              'birthdate' => patient.birthdate,
              'gender' => patient.gender
            }
          end
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
          ActiveRecord::Base.connection.select_all <<~SQL
            SELECT orders.patient_id,
                   disaggregated_age_group(patient.birthdate,
                                                  DATE(#{ActiveRecord::Base.connection.quote(end_date)})) AS age_group,
                   patient.birthdate,
                   patient.gender,
                   patient_identifier.identifier AS arv_number
            FROM orders
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
              WHERE orders.start_date <= DATE(#{ActiveRecord::Base.connection.quote(end_date)}) - INTERVAL 12 MONTH
                AND orders.voided = 0
              GROUP BY orders.patient_id
            ) AS latest_patient_order_date
              ON latest_patient_order_date.patient_id = orders.patient_id
              AND latest_patient_order_date.start_date = orders.start_date
            INNER JOIN temp_earliest_start_date AS patient ON patient.patient_id = orders.patient_id
            INNER JOIN temp_patient_outcomes AS outcomes
              ON outcomes.patient_id = patient.patient_id
              AND outcomes.cum_outcome = 'On antiretrovirals'
            LEFT JOIN patient_identifier
              ON patient_identifier.patient_id = orders.patient_id
              AND patient_identifier.identifier_type IN (#{pepfar_patient_identifier_type.to_sql})
              AND patient_identifier.voided = 0
            WHERE orders.start_date < DATE(#{ActiveRecord::Base.connection.quote(end_date)}) - INTERVAL 12 MONTH
            GROUP BY orders.patient_id
          SQL
        end

        ##
        # Returns all patients that have been on ART for at least 6 months and have never had a Viral Load.
        def find_patients_due_for_initial_viral_load
          ActiveRecord::Base.connection.select_all <<~SQL
            SELECT patient.patient_id,
                   disaggregated_age_group(patient.birthdate,
                                                  DATE(#{ActiveRecord::Base.connection.quote(end_date)})) AS age_group,
                   patient.birthdate,
                   patient.gender,
                   patient_identifier.identifier AS arv_number
            FROM temp_earliest_start_date AS patient
            INNER JOIN temp_patient_outcomes AS outcomes
              ON outcomes.patient_id = patient.patient_id
              AND outcomes.cum_outcome = 'On antiretrovirals'
            INNER JOIN patient_identifier
              ON patient_identifier.patient_id = patient.patient_id
              AND patient_identifier.identifier_type IN (#{pepfar_patient_identifier_type.to_sql})
              AND patient_identifier.voided = 0
            WHERE patient.patient_id NOT IN (
              SELECT DISTINCT orders.patient_id FROM orders
              INNER JOIN order_type ON order_type.order_type_id = orders.order_type_id AND order_type.name = 'Lab'
              INNER JOIN obs ON orders.order_id = obs.order_id AND obs.voided = 0
              INNER JOIN concept_name ON concept_name.concept_id = obs.concept_id AND concept_name.name = 'Test type' AND concept_name.voided = 0
              INNER JOIN concept_name AS test_name ON test_name.concept_id = obs.value_coded AND test_name.name = 'HIV Viral Load' AND test_name.voided = 0
              WHERE orders.start_date <= DATE(#{ActiveRecord::Base.connection.quote(end_date)}) - INTERVAL 12 MONTH
                AND orders.concept_id IN (SELECT concept_id FROM concept_name WHERE name IN ('Blood', 'DBS (Free drop to DBS card)', 'DBS (Using capillary tube)'))
                AND orders.voided = 0
            ) AND patient.earliest_start_date <= DATE(#{ActiveRecord::Base.connection.quote(end_date)}) - INTERVAL 6 MONTH
            GROUP BY patient.patient_id
          SQL
        end

        ##
        # Find all patients that are on treatment with at least one VL before end of reporting period.
        def find_patients_with_viral_load
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
                AND orders.voided = 0
              GROUP BY orders.patient_id
            ) AS latest_patient_order_date
              ON latest_patient_order_date.patient_id = orders.patient_id
              AND latest_patient_order_date.start_date = orders.start_date
            INNER JOIN temp_earliest_start_date AS patient ON patient.patient_id = orders.patient_id
            INNER JOIN temp_patient_outcomes AS outcomes
              ON outcomes.patient_id = patient.patient_id
              AND outcomes.cum_outcome = 'On antiretrovirals'
            LEFT JOIN patient_identifier
              ON patient_identifier.patient_id = orders.patient_id
              AND patient_identifier.identifier_type IN (#{pepfar_patient_identifier_type.to_sql})
              AND patient_identifier.voided = 0
            WHERE orders.start_date < DATE(#{ActiveRecord::Base.connection.quote(end_date)}) + INTERVAL 1 DAY
              AND orders.start_date >= DATE(#{ActiveRecord::Base.connection.quote(start_date)})
            GROUP BY orders.patient_id
          SQL
        end

        ##
        # Returns a Relation of all viral load tests.
        def find_viral_load_tests
          Lab::LabTest.where(value_coded: concept('Viral load'))
        end

        def find_emastercard_patient_results
          ActiveRecord::Base.connection.select_all <<~SQL
            SELECT obs.person_id AS patient_id,
                   patient_identifier.identifier AS arv_number,
                   patient.birthdate,
                   patient.gender,
                   disaggregated_age_group(patient.birthdate, #{ActiveRecord::Base.connection.quote(end_date)}) AS age_group,
                   obs.value_numeric AS result_value
            FROM obs
            INNER JOIN encounter ON encounter.encounter_id = obs.encounter_id AND encounter.voided = 0
            INNER JOIN encounter_type ON encounter_type.encounter_type_id = encounter.encounter_type AND encounter_type.name = 'Lab'
            INNER JOIN temp_earliest_start_date AS patient ON patient.patient_id = obs.person_id
            INNER JOIN temp_patient_outcomes
              ON temp_patient_outcomes.patient_id = obs.person_id
              AND temp_patient_outcomes.cum_outcome = 'On antiretrovirals'
            LEFT JOIN patient_identifier
              ON patient_identifier.patient_id = obs.person_id
              AND patient_identifier.voided = 0
              AND patient_identifier.identifier_type IN (#{pepfar_patient_identifier_type.to_sql})
            INNER JOIN (
              SELECT obs.person_id, MAX(obs.obs_datetime) AS obs_datetime
              FROM obs
              INNER JOIN encounter ON encounter.encounter_id = obs.encounter_id AND encounter.voided = 0
              INNER JOIN encounter_type ON encounter_type.encounter_type_id = encounter.encounter_type AND encounter_type.name = 'Lab'
              WHERE obs.concept_id IN (#{concept('Viral load').to_sql})
                AND obs.obs_datetime > DATE(#{ActiveRecord::Base.connection.quote(start_date)}) - INTERVAL 1 DAY
                AND obs.obs_datetime < DATE(#{ActiveRecord::Base.connection.quote(end_date)}) + INTERVAL 1 DAY
                AND obs.voided = 0
              GROUP BY obs.person_id
            ) AS latest_results
              ON latest_results.person_id = obs.person_id
              AND latest_results.obs_datetime = obs.obs_datetime
            WHERE obs.concept_id IN (#{concept('Viral load').to_sql})
              AND obs.value_numeric IS NOT NULL
              AND obs.voided = 0
            GROUP BY obs.person_id
          SQL
        end

        def concept(name)
          ConceptName.where(name: name).select(:concept_id)
        end
      end
    end
  end
end
