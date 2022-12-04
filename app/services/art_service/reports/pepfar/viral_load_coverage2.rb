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
        attr_reader :start_date, :end_date, :occupation

        include Utils

        def initialize(start_date:, end_date:, **kwargs)
          @start_date = start_date&.to_date
          raise InvalidParameterError, 'start_date is required' unless @start_date

          @end_date = end_date&.to_date || @start_date + 12.months
          raise InvalidParameterError, "start_date can't be greater than end_date" if @start_date > @end_date

          @occupation = kwargs.delete(:occupation)
        end

        def find_report
          report = init_report
          build_report(report)
          report
        end

        def vl_maternal_status(patient_list)
          return { FP: [], FBf: [] } if patient_list.blank?

          pregnant = pregnant_women(patient_list).map { |woman| woman['person_id'].to_i }
          return { FP: pregnant, FBf: [] } if (patient_list - pregnant).blank?

          feeding = breast_feeding(patient_list - pregnant).map { |woman| woman['person_id'].to_i }

          {
            FP: pregnant,
            FBf: feeding
          }
        end

        def process_due_people
          clients = []
          start = Time.now
          results = clients_on_art
          # get all clients that are females from results
          maternal_status = vl_maternal_status(results.map { |patient| patient['patient_id'] if patient['gender'] == 'F' }.compact)
          Parallel.each(results, in_threads: 20) do |patient|
            # get client extra details
            result = extra_information(patient['patient_id'])
            patient['defaulter_date'] = result['defaulter_date']
            patient['current_regimen'] = result['current_regimen']
            patient['art_start_date'] = result['art_start_date']
            patient['maternal_status'] = maternal_status[:FP].include?(patient['patient_id']) ? 'FP' : (maternal_status[:FBf].include?(patient['patient_id']) ? 'FBf' : nil)
            unless patient['defaulter_date'].blank?
              next if patient['defaulter_date'] < end_date - 12.months
            end
            next if result['art_start_date'].blank?
            next if result['art_start_date'].to_date > end_date - 6.months
            next if remove_adverse_outcome_patient?(patient)

            clients << patient
          end
          end_time = Time.now
          Rails.logger.info "Time taken to process #{results.length} clients: #{end_time - start} seconds. These are the clients returned: #{clients.length}"
          clients
        end

        private

        def remove_adverse_outcome_patient?(patient)
          return false unless adverse_outcomes.include?(patient['state'].to_i)

          last_date = patient['vl_order_date'] || patient['art_start_date']
          return false if patient['vl_order_date'].present? && last_date.to_date >= start_date && last_date.to_date <= end_date

          length = 12
          length = 6 if patient['maternal_status'] == 'FP'
          length = 6 if patient['maternal_status'] == 'FBf'
          length = 6 if patient['current_regimen'].to_s.match(/P/i)

          return false if last_date.to_date + length.months < patient['outcome_date'].to_date

          true
        end

        def pregnant_women(patient_list)
          ActiveRecord::Base.connection.select_all <<~SQL
            SELECT o.person_id, o.value_coded
            FROM obs o
            INNER JOIN encounter e ON e.encounter_id = o.encounter_id AND e.voided = 0 AND e.encounter_type IN (#{encounter_types.to_sql})
            INNER JOIN person p ON o.person_id = e.patient_id AND LEFT(p.gender, 1) = 'F'
            INNER JOIN (
              SELECT person_id, MAX(obs_datetime) AS obs_datetime
              FROM obs
              INNER JOIN encounter ON encounter.encounter_id = obs.encounter_id AND encounter.encounter_type IN (#{encounter_types.to_sql}) AND encounter.voided = 0
              WHERE obs.concept_id IN (#{pregnant_concepts.to_sql})
                AND obs.obs_datetime BETWEEN DATE(#{ActiveRecord::Base.connection.quote(start_date)}) AND DATE(#{ActiveRecord::Base.connection.quote(end_date)}) + INTERVAL 1 DAY
                AND obs.voided = 0
              GROUP BY person_id
            ) AS max_obs ON max_obs.person_id = o.person_id AND max_obs.obs_datetime = o.obs_datetime
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
            INNER JOIN person p ON o.person_id = e.patient_id AND LEFT(p.gender, 1) = 'F'
            INNER JOIN (
              SELECT person_id, MAX(obs_datetime) AS obs_datetime
              FROM obs
              INNER JOIN encounter ON encounter.encounter_id = obs.encounter_id AND encounter.encounter_type IN (#{encounter_types.to_sql}) AND encounter.voided = 0
              WHERE obs.concept_id IN (#{breast_feeding_concepts.to_sql})
                AND obs.obs_datetime BETWEEN DATE(#{ActiveRecord::Base.connection.quote(start_date)}) AND DATE(#{ActiveRecord::Base.connection.quote(end_date)}) + INTERVAL 1 DAY
                AND obs.voided = 0
              GROUP BY person_id
            ) AS max_obs ON max_obs.person_id = o.person_id AND max_obs.obs_datetime = o.obs_datetime
            WHERE o.concept_id IN (#{breast_feeding_concepts.to_sql})
              AND o.voided = 0
              AND o.value_coded IN (#{yes_concepts.join(',')})
              AND o.person_id IN (#{patient_list.join(',')})
            GROUP BY o.person_id
          SQL
        end

        def build_report(report)
          clients = process_due_people
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

        def clients_on_art
          ActiveRecord::Base.connection.select_all <<~SQL
            SELECT
              ab.patient_id,
              disaggregated_age_group(p.birthdate, DATE(#{ActiveRecord::Base.connection.quote(end_date)})) AS age_group,
              -- patient_current_regimen(ab.patient_id, DATE(#{ActiveRecord::Base.connection.quote(end_date)})) AS current_regimen,
              -- date_antiretrovirals_started(ab.patient_id, DATE(#{ActiveRecord::Base.connection.quote(end_date)})) AS art_start_date,
              -- current_pepfar_defaulter_date(ab.patient_id, DATE(#{ActiveRecord::Base.connection.quote(end_date)})) AS defaulter_date,
              p.birthdate,
              p.gender,
              pid.identifier AS arv_number,
              current_state.state,
              current_state.start_date outcome_date,
              current_order.start_date vl_order_date
            FROM orders ab
            INNER JOIN person p ON p.person_id = ab.patient_id AND p.voided = 0
            INNER JOIN drug_order dor ON dor.order_id = ab.order_id AND dor.quantity > 0
            INNER JOIN arv_drug ad ON dor.drug_inventory_id = ad.drug_id
            INNER JOIN patient_program pp ON pp.patient_id = ab.patient_id AND pp.voided = 0 AND pp.program_id = 1
            INNER JOIN (
              SELECT a.patient_program_id, a.state, a.start_date, a.end_date
              FROM patient_state a
              LEFT OUTER JOIN patient_state b ON a.patient_program_id = b.patient_program_id
              AND a.start_date < b.start_date
              AND b.voided = 0
              WHERE b.patient_program_id IS NULL AND a.end_date IS NULL AND a.voided = 0
            ) current_state ON current_state.patient_program_id = pp.patient_program_id
            LEFT OUTER JOIN orders b ON ab.patient_id = b.patient_id
            AND ab.order_id = b.order_id
            AND ab.auto_expire_date < b.auto_expire_date
            AND b.voided = 0 AND b.order_type_id = 1
            #{current_occupation('ab.patient_id')}
            LEFT JOIN patient_identifier pid ON pid.patient_id = pp.patient_id AND pid.identifier_type IN (#{pepfar_patient_identifier_type.to_sql}) AND pid.voided = 0
            LEFT JOIN (
              SELECT ab.patient_id, MAX(ab.start_date) start_date
              FROM orders ab
              INNER JOIN concept_name
                ON concept_name.concept_id = ab.concept_id
                AND concept_name.name IN ('Blood', 'DBS (Free drop to DBS card)', 'DBS (Using capillary tube)', '50:50 Normal Plasma')
                AND concept_name.voided = 0
              LEFT OUTER JOIN orders b ON ab.patient_id = b.patient_id
              AND ab.order_id = b.order_id
              AND ab.start_date < b.start_date
              AND b.voided = 0
              WHERE b.patient_id IS NULL AND ab.voided = 0 AND ab.order_type_id = 4 AND ab.start_date < DATE(#{ActiveRecord::Base.connection.quote(end_date)}) + INTERVAL 1 DAY
              GROUP BY ab.patient_id
            ) current_order ON current_order.patient_id = ab.patient_id
            WHERE b.patient_id IS NULL
              AND ab.voided = 0 #{occupation_filter(occupation)}
              AND ab.start_date < DATE(#{ActiveRecord::Base.connection.quote(end_date)}) + INTERVAL 1 DAY
              AND p.person_id NOT IN (#{drug_refills_and_external_consultation_list})
              AND ((current_state.state IN (#{adverse_outcomes.join(',')}) AND current_state.start_date >= (DATE(#{ActiveRecord::Base.connection.quote(end_date)}) - INTERVAL 12 MONTH)) OR current_state.state IN (7, 1, 87, 120, 136))
            GROUP BY ab.patient_id;
          SQL
        end

        def extra_information(patient_id)
          ActiveRecord::Base.connection.select_one <<~SQL
            SELECT patient_current_regimen(#{patient_id}, DATE(#{ActiveRecord::Base.connection.quote(end_date)})) AS current_regimen,
            date_antiretrovirals_started(#{patient_id}, DATE(#{ActiveRecord::Base.connection.quote(end_date)})) AS art_start_date,
            current_pepfar_defaulter_date(#{patient_id}, DATE(#{ActiveRecord::Base.connection.quote(end_date)})) AS defaulter_date
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
              AND concept_name.name IN ('Blood', 'DBS (Free drop to DBS card)', 'DBS (Using capillary tube)', 'Plasma')
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
                AND concept_name.name IN ('Blood', 'DBS (Free drop to DBS card)', 'DBS (Using capillary tube)', 'Plasma')
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
              AND orders.patient_id IN (#{clients.push(0).join(',')})
            GROUP BY orders.patient_id
          SQL
        end

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
