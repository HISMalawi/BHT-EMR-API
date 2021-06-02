# frozen_string_literal: true

module ARTService
  module Reports
    ##
    # Returns all ART patients whose most recent viral load is high
    # in a reporting period.
    #
    # High viral load is defined as a viral load with a numeric value
    # equal to or exceeding 800, or a result value of >LDL.
    class HighViralLoadPatients
      def initialize(start_date:, end_date:, **_kwargs)
        @start_date = start_date
        @end_date = end_date
      end

      def find_report
        start_date = ActiveRecord::Base.connection.quote(@start_date)
        end_date = ActiveRecord::Base.connection.quote(@end_date)

        ActiveRecord::Base.connection.select_all <<~SQL
          SELECT orders.patient_id,
                 patient_identifier.identifier AS arv_number,
                 person.birthdate AS birthdate,
                 cohort_disaggregated_age_group(person.birthdate, #{end_date}) AS age_group,
                 person.gender AS gender,
                 orders.start_date AS order_date,
                 COALESCE(orders.discontinued_date, orders.start_date) AS specimen_drawn_date,
                 test_results_obs.obs_datetime AS result_date,
                 COALESCE(test_result_measure_obs.value_modifier, '=') AS result_modifier,
                 COALESCE(test_result_measure_obs.value_numeric, test_result_measure_obs.value_text) AS result
          FROM orders
          LEFT JOIN patient_identifier
            ON patient_identifier.patient_id = orders.patient_id
            AND patient_identifier.voided = 0
            AND patient_identifier.identifier_type IN (
              SELECT patient_identifier_type_id FROM patient_identifier_type WHERE name = 'ARV Number' AND retired = 0
            )
          INNER JOIN person
            ON person.person_id = orders.patient_id
            AND person.voided = 0
          /* For each lab order find an HIV Viral Load test */
          INNER JOIN obs AS test_obs
            ON test_obs.order_id = orders.order_id
            AND test_obs.concept_id IN (
              SELECT concept_id FROM concept_name INNER JOIN concept USING (concept_id)
              WHERE concept_name.name = 'Test type' AND concept.retired = 0 AND concept_name.voided = 0
            )
            AND test_obs.value_coded IN (
              SELECT concept_id FROM concept_name INNER JOIN concept USING (concept_id)
              WHERE concept_name.name = 'Viral load' AND concept.retired = 0 AND concept_name.voided = 0
            )
            AND test_obs.voided = 0
          /* Select each test's results */
          INNER JOIN obs AS test_results_obs
            ON test_results_obs.obs_group_id = test_obs.obs_id
            AND test_results_obs.concept_id IN (
              SELECT concept_id FROM concept_name INNER JOIN concept USING (concept_id)
              WHERE concept_name.name = 'Lab test result' AND concept.retired = 0 AND concept_name.voided = 0
            )
            AND test_results_obs.voided = 0
            AND test_results_obs.obs_datetime >= DATE(#{start_date})
            AND test_results_obs.obs_datetime < DATE(#{end_date}) + INTERVAL 1 DAY
          /* Limit the test result's to each patient's most recent result. */
          INNER JOIN (
            SELECT MAX(obs_datetime) AS obs_datetime,
                   person_id
            FROM obs
            INNER JOIN orders
              ON orders.order_id = obs.order_id
              AND orders.order_type_id IN (SELECT order_type_id FROM order_type WHERE name = 'Lab' AND retired = 0)
              AND orders.concept_id IN (
                SELECT concept_id FROM concept_name INNER JOIN concept USING (concept_id)
                WHERE concept_name.name = 'Blood' AND concept.retired = 0 AND concept_name.voided = 0
              )
              AND orders.voided = 0
            WHERE obs.concept_id IN (
                SELECT concept_id FROM concept_name INNER JOIN concept USING (concept_id)
                WHERE concept_name.name = 'Lab test result' AND concept.retired = 0 AND concept_name.voided = 0
              )
              AND obs.voided = 0
              AND obs.obs_datetime >= DATE(#{start_date})
              AND obs.obs_datetime < DATE(#{end_date}) + INTERVAL 1 DAY
            GROUP BY person_id
          ) AS max_test_results
            ON max_test_results.obs_datetime = test_results_obs.obs_datetime
            AND max_test_results.person_id = test_results_obs.person_id
          /* Find a viral load measure that can be classified as High on the test results */
          INNER JOIN obs AS test_result_measure_obs
            ON test_result_measure_obs.obs_group_id = test_results_obs.obs_id
            AND test_result_measure_obs.concept_id IN (
              SELECT concept_id FROM concept_name INNER JOIN concept USING (concept_id)
              WHERE concept_name.name = 'Viral load' AND concept.retired = 0 AND concept_name.voided = 0
            )
            AND (test_result_measure_obs.value_numeric >= 800
                 OR (test_result_measure_obs.value_modifier = '>' AND test_result_measure_obs.value_text = 'LDL'))
            AND test_result_measure_obs.voided = 0
          WHERE orders.concept_id IN (
              SELECT concept_id FROM concept_name INNER JOIN concept USING (concept_id)
              WHERE concept_name.name = 'Blood' AND concept.retired = 0 AND concept_name.voided = 0
            )
            AND orders.order_type_id IN (SELECT order_type_id FROM order_type WHERE name = 'Lab' AND retired = 0)
            AND orders.voided = 0
          GROUP BY orders.patient_id
        SQL
      end
    end
  end
end
