# frozen_string_literal: true

# rubocop:disable Metrics/BlockLength, Metrics/ClassLength, Style/Documentation
module ARTService
  module Reports
    module Pepfar
      class TxTB
        attr_accessor :start_date, :end_date, :report

        include Utils

        def initialize(start_date:, end_date:, **_kwargs)
          @start_date = start_date.to_date.strftime('%Y-%m-%d 00:00:00')
          @end_date = end_date.to_date.strftime('%Y-%m-%d 23:59:59')
        end

        def find_report
          init_report
          tx_curr = find_patients_alive_and_on_art
          tx_curr.each { |patient| report[patient['age_group']][:tx_curr] << patient['patient_id'] }
          screened = tb_screened(tx_curr.map { |patient| patient['patient_id'] })
          pepfar_age_groups.each do |age_group|
            screened.each do |patient|
              next unless patient['age_group'] == age_group

              start_date = patient['earliest_start_date']
              enrollment_date = patient['date_enrolled']
              tb_status_id = patient['tb_status']

              tb_status_name = ConceptName.find_by_concept_id(tb_status_id).name
              next unless tb_status_name.present?

              key_prefix = new_on_art(start_date, enrollment_date) ? :new : :prev

              started_tb_key = :"started_tb_#{key_prefix}"
              sceen_pos_key = :"sceen_pos_#{key_prefix}"
              sceen_neg_key = :"sceen_neg_#{key_prefix}"

              if ['RX', 'Confirmed TB on treatment'].include?(tb_status_name)
                report[age_group][started_tb_key] << patient['person_id']
              elsif ['TB Suspected', 'Confirmed TB NOT on treatment', 'sup', 'Norx'].include?(tb_status_name)
                report[age_group][sceen_pos_key] << patient['person_id']
              elsif tb_status_name == 'TB NOT suspected'
                report[age_group][sceen_neg_key] << patient['person_id']
              end

              report[age_group][:specimens_sent] << patient['person_id'] if patient['test'].present? 
              next unless patient['measures'].present?

              tests_results = patient['measures'].split(',')
              tests_results.each do |result|
                measure, modifier, value = result.split(':')
                report[age_group][:gene_xpert_test_only] << patient['person_id'] if /Gene Xpert/.match?(measure)
                report[age_group][:smear_test_only] << patient['person_id'] if /Smear/.match?(measure)
                report[age_group][:lam] << patient['person_id'] if /Lam/.match?(measure)

                report[age_group][:other] << patient['person_id'] unless /Lam|Smear|Gene Xpert/.match?(measure)
                report[age_group][:positive_results] << patient['person_id'] if value == 'positive'
              end
            end
          end
          report
        end

        def init_report
          @report = pepfar_age_groups.each_with_object({}) do |age_group, report|
            report[age_group] = {
              tx_curr: [],
              sceen_pos_new: [],
              sceen_neg_new: [],
              started_tb_new: [],
              specimens_sent: [],
              smear_test_only: [],
              gene_xpert_test_only: [],
              lam: [],
              other: [],
              positive_results: [],
              sceen_pos_prev: [],
              sceen_neg_prev: [],
              started_tb_prev: []
            }
          end
        end

        def arv_concepts
          @arv_concepts ||= ConceptSet.where(concept_set: ConceptName.where(name: 'Antiretroviral drugs')
                                               .select(:concept_id))
                                      .collect(&:concept_id).join(',')
        end

        def find_patients_alive_and_on_art
          ActiveRecord::Base.connection.select_all <<~SQL
            SELECT pp.patient_id, coalesce(o.value_datetime, min(art_order.start_date)) art_start_date, disaggregated_age_group(p.birthdate, DATE('#{end_date.to_date}')) age_group
            FROM patient_program pp
            INNER JOIN person p ON p.person_id = pp.patient_id AND p.voided = 0
            INNER JOIN patient_state ps ON ps.patient_program_id = pp.patient_program_id AND ps.voided = 0 AND ps.state = 7 -- ON ART
            INNER JOIN orders art_order ON art_order.patient_id = pp.patient_id
              AND art_order.start_date >= DATE('#{start_date}')
              AND art_order.start_date < DATE('#{end_date}') + INTERVAL 1 DAY
              AND art_order.voided = 0
              AND art_order.order_type_id = 1 -- Drug order
              AND art_order.concept_id IN (#{arv_concepts})
            INNER JOIN drug_order do ON do.order_id = art_order.order_id AND do.quantity > 0
            LEFT JOIN encounter e ON e.patient_id = pp.patient_id
              AND e.encounter_type = 9 -- HIV CLINIC REGISTRATION
              AND e.voided = 0
              AND e.encounter_datetime < DATE('#{end_date}') + INTERVAL 1 DAY
              AND e.program_id = 1 -- HIV program
            LEFT JOIN obs o ON o.person_id = pp.patient_id
              AND o.concept_id = 2516 -- ART start date
              AND o.encounter_id = e.encounter_id
              AND o.voided = 0
            WHERE pp.patient_id NOT IN (
              SELECT o.patient_id
              FROM orders o
              INNER JOIN drug_order do ON do.order_id = o.order_id AND do.quantity > 0
              WHERE o.order_type_id = 1 -- Drug order
                AND o.voided  = 0
                AND o.concept_id IN (#{arv_concepts})
                AND o.start_date < DATE('#{start_date}')
              GROUP BY o.patient_id
            )
            AND pp.program_id = 1 -- HIV program
            GROUP BY pp.patient_id
          SQL
        end

        def new_on_art(earliest_start_date, min_date)
          med_start_date = min_date.to_date
          med_end_date = (earliest_start_date.to_date + 90.day).to_date

          return true if med_start_date >= earliest_start_date.to_date && med_start_date < med_end_date

          false
        end

        def tb_screened(patient_ids)
          return [] if patient_ids.blank?

          ActiveRecord::Base.connection.select_all <<~SQL
            SELECT DISTINCT p.person_id, o.value_coded AS tb_status, disaggregated_age_group(p.birthdate, DATE(#{ActiveRecord::Base.connection.quote(end_date.to_date)})) AS age_group, earliest_start_date_at_clinic(p.person_id) AS earliest_start_date,
            date_antiretrovirals_started(p.person_id, DATE(#{ActiveRecord::Base.connection.quote(end_date.to_date)})) AS date_enrolled,
            tb_tests.*
            FROM person p
            LEFT JOIN (
                SELECT lab_result_obs.person_id as patient, lab_result_obs.obs_id AS result_id,
                    lab_result_obs.obs_datetime AS result_date,
                    lab_result_obs.person_id AS patient_id,
                    orders.start_date AS order_date,
                    specimen_concept.name AS test,
                    GROUP_CONCAT(DISTINCT CONCAT(measure_concept.name, ':', COALESCE(measure.value_modifier, '='), ':', COALESCE(measure.value_numeric, measure.value_text, ''))
                                  SEPARATOR ',') AS measures
              FROM obs AS lab_result_obs
              INNER JOIN orders
                ON orders.order_id = lab_result_obs.order_id
                AND orders.voided = 0
              INNER JOIN obs AS test_obs
              ON test_obs.order_id = orders.order_id
              AND test_obs.concept_id IN (
                SELECT concept_id FROM concept_name INNER JOIN concept USING (concept_id)
                WHERE concept_name.name = 'Test type' AND concept.retired = 0 AND concept_name.voided = 0
              )
              AND test_obs.value_coded IN (
                SELECT concept_id FROM concept_name INNER JOIN concept USING (concept_id)
                WHERE concept_name.name in ('TB Tests', 'Urine Lam', 'TB Microscopic Exam') AND concept.retired = 0 AND concept_name.voided = 0
              )
            AND test_obs.voided = 0
              INNER JOIN (
                SELECT concept_id, name FROM concept_name INNER JOIN concept USING (concept_id) WHERE concept.retired = 0 GROUP BY concept_id
              ) AS specimen_concept
                ON specimen_concept.concept_id = orders.concept_id
              LEFT JOIN obs AS measure
                ON measure.obs_group_id = lab_result_obs.obs_id
                AND measure.voided = 0
              LEFT JOIN (
                SELECT concept_id, name
                FROM concept_name
                INNER JOIN concept USING (concept_id)
                WHERE concept.retired = 0
                  AND name NOT LIKE 'Lab test result'
                GROUP BY concept_id
              ) AS measure_concept
                ON measure_concept.concept_id = measure.concept_id
              WHERE lab_result_obs.voided = 0
                AND lab_result_obs.obs_datetime >= DATE(#{ActiveRecord::Base.connection.quote(start_date.to_date)})
                AND lab_result_obs.obs_datetime < DATE(#{ActiveRecord::Base.connection.quote(end_date.to_date)}) + INTERVAL 1 DAY
              GROUP BY orders.order_id
            ) as tb_tests ON tb_tests.patient = p.person_id
            INNER JOIN obs o ON o.person_id = p.person_id and o.voided = 0
            WHERE o.concept_id = #{ConceptName.find_by_name('TB status').concept_id}
            AND p.person_id IN(#{patient_ids.join(',')})
          SQL
        end
      end
    end
  end
end

# rubocop:enable Metrics/BlockLength, Metrics/ClassLength, Style/Documentation
