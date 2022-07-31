# frozen_string_literal: true

module ARTService
  module Reports
    module Pepfar
      # this module returns all the patient records on when
      # when the patient started ART
      # plus the last viral load result
      module PatientStartVL
        def self.get_patients_last_vl_and_latest_result(patient_ids, end_date)
          ids = patient_ids.push(0).join(',')
          ActiveRecord::Base.connection.select_one <<~SQL
            SELECT vl_test_obs.person_id, vl_test_obs.obs_datetime AS mr_viral_sample, latest_result_obs.result AS mr_vl_result, latest_result_obs.result_date AS mr_vl_result_date
            FROM obs vl_test_obs
            INNER JOIN (
              SELECT person_id, obs_datetime
              FROM obs
              WHERE concept_id = 2429 AND value_coded IS NOT NULL AND voided = 0
            ) AS reason_for_test_obs ON reason_for_test_obs.person_id = vl_test_obs.person_id AND DATE(reason_for_test_obs.obs_datetime) = DATE(vl_test_obs.obs_datetime)
            LEFT JOIN(
              SELECT lab_result_obs.obs_datetime AS result_date,
              CONCAT (COALESCE(measure.value_modifier, '='),' ',COALESCE(measure.value_numeric, measure.value_text, '')) AS result,
              lab_result_obs.person_id AS person_id
              FROM obs AS lab_result_obs
              INNER JOIN orders
                ON orders.order_id = lab_result_obs.order_id
                AND orders.voided = 0
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
              AND measure.person_id IN (#{ids})
              AND (measure.value_numeric IS NOT NULL || measure.value_text IS NOT NULL)
              AND lab_result_obs.obs_datetime <= '#{end_date.to_date.strftime('%Y-%m-%d 23:59:59')}'
              GROUP BY lab_result_obs.person_id
              ORDER BY lab_result_obs.obs_datetime DESC
            ) AS latest_result_obs ON latest_result_obs.person_id = vl_test_obs.person_id
            WHERE vl_test_obs.concept_id = 9737
            AND vl_test_obs.value_coded = 856
            AND vl_test_obs.voided = 0
            AND vl_test_obs.obs_datetime <= '#{end_date.to_date.strftime('%Y-%m-%d 23:59:59')}'
            AND vl_test_obs.person_id IN (#{ids})
            GROUP BY vl_test_obs.person_id
            ORDER BY vl_test_obs.obs_datetime
          SQL
        end
      end
    end
  end
end
