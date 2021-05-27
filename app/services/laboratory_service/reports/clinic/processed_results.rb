# frozen_string_literal: true

module LaboratoryService
  module Reports
    module Clinic
      ##
      # Pull all orders with a result
      class ProcessedResults
        attr_reader :start_date, :end_date

        def initialize(start_date:, end_date:, **_kwargs)
          @start_date = start_date.to_date
          @end_date = end_date.to_date
        end

        def read
          query.map do |result|
            {
              accession_number: result['accession_number'],
              result_id: result['result_id'],
              result_date: result['result_date'],
              patient_id: result['patient_id'],
              order_date: result['order_date'],
              test: result['test'],
              reason_for_test: result['reason_for_test'],
              reason_for_test_obs_id: result['reason_for_test_obs_id'],
              arv_number: result['arv_number'],
              birthdate: result['birthdate'],
              age_group: result['age_group'],
              measures: result['measures'].split(',').map do |measure|
                name, modifier, value = measure.split(':')

                { name: name, modifier: modifier, value: value }
              end
            }
          end
        end

        private

        def query
          start_date = ActiveRecord::Base.connection.quote(@start_date)
          end_date = ActiveRecord::Base.connection.quote(@end_date)

          ActiveRecord::Base.connection.select_all <<~SQL
            SELECT lab_result_obs.obs_id AS result_id,
                   lab_result_obs.obs_datetime AS result_date,
                   lab_result_obs.person_id AS patient_id,
                   orders.start_date AS order_date,
                   specimen_concept.name AS test,
                   COALESCE(reason_for_test.name, reason_for_test_obs.value_text) AS reason_for_test,
                   reason_for_test_obs.obs_id AS reason_for_test_obs_id,
                   patient_identifier.identifier AS arv_number,
                   person.birthdate,
                   cohort_disaggregated_age_group(person.birthdate, #{end_date}) AS age_group,
                   GROUP_CONCAT(DISTINCT CONCAT(measure_concept.name, ':', COALESCE(measure.value_modifier, '='), ':', COALESCE(measure.value_numeric, measure.value_text, ''))
                                SEPARATOR ',') AS measures,
                   orders.accession_number
            FROM obs AS lab_result_obs
            INNER JOIN orders
              ON orders.order_id = lab_result_obs.order_id
              AND orders.voided = 0
            INNER JOIN (
              SELECT concept_id, name FROM concept_name INNER JOIN concept USING (concept_id) WHERE concept.retired = 0 GROUP BY concept_id
            ) AS specimen_concept
              ON specimen_concept.concept_id = orders.concept_id
            INNER JOIN obs AS reason_for_test_obs
              ON reason_for_test_obs.order_id = lab_result_obs.order_id
              AND reason_for_test_obs.voided = 0
              AND reason_for_test_obs.concept_id IN (SELECT concept_id FROM concept_name WHERE name LIKE 'Reason for test')
            LEFT JOIN (
              SELECT concept_id, name FROM concept_name INNER JOIN concept USING (concept_id) WHERE concept.retired = 0 GROUP BY concept_id
            ) AS reason_for_test
              ON reason_for_test.concept_id = reason_for_test_obs.value_coded
            INNER JOIN person
              ON person.person_id = lab_result_obs.person_id
              AND person.voided = 0
            LEFT JOIN patient_identifier
              ON patient_identifier.patient_id = lab_result_obs.person_id
              AND patient_identifier.voided = 0
              AND patient_identifier.identifier_type IN (SELECT patient_identifier_type_id FROM patient_identifier_type WHERE name LIKE 'ARV Number')
            INNER JOIN obs AS measure
              ON measure.obs_group_id = lab_result_obs.obs_id
              AND measure.voided = 0
            INNER JOIN (
              SELECT concept_id, name
              FROM concept_name
              INNER JOIN concept USING (concept_id)
              WHERE concept.retired = 0
                AND name NOT LIKE 'Lab test result'
              GROUP BY concept_id
            ) AS measure_concept
              ON measure_concept.concept_id = measure.concept_id
            WHERE lab_result_obs.voided = 0
              AND lab_result_obs.obs_datetime >= #{start_date}
              AND lab_result_obs.obs_datetime < #{end_date}
            GROUP BY lab_result_obs.obs_id
          SQL
        end
      end
    end
  end
end
