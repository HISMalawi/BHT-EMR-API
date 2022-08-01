# frozen_string_literal: true

module ARTService
  module Reports
    module Pepfar
      # this module returns all the patient records on when
      # when the patient started ART
      # plus the last viral load result
      class PatientStartVL
        def get_patients_last_vl_and_latest_result(patient_ids, end_date)
          ids = patient_ids.push(0).join(',')
          ActiveRecord::Base.connection.select_all <<~SQL
            SELECT vl_test_obs.person_id AS patient_id,
            DATE(vl_test_obs.obs_datetime) AS mr_viral_sample,
            latest_result_obs.result AS mr_vl_result,
            DATE(latest_result_obs.result_date) AS mr_vl_result_date,
            patient_start_date(vl_test_obs.person_id) AS art_start_date,
            p.birthdate AS birthdate,
            p.gender,
            pi.identifier
            FROM obs vl_test_obs
            INNER JOIN person p ON p.person_id = vl_test_obs.person_id
            LEFT JOIN patient_identifier pi ON pi.patient_id = vl_test_obs.person_id AND pi.voided = 0 AND pi.identifier_type = 4
            INNER JOIN (
              SELECT person_id, obs_datetime
              FROM obs
              WHERE concept_id = 2429 AND value_coded IS NOT NULL AND voided = 0
            ) AS reason_for_test_obs ON reason_for_test_obs.person_id = vl_test_obs.person_id AND DATE(reason_for_test_obs.obs_datetime) = DATE(vl_test_obs.obs_datetime)
            LEFT JOIN(
              SELECT lab_result_obs.obs_datetime AS result_date,
              CONCAT (COALESCE(lab_result_obs.value_modifier, '='),' ',COALESCE(lab_result_obs.value_numeric, lab_result_obs.value_text, '')) AS result,
              lab_result_obs.person_id AS person_id
              FROM obs AS lab_result_obs
              WHERE lab_result_obs.concept_id = 856 AND lab_result_obs.obs_group_id IS NOT NULL AND lab_result_obs.voided = 0
              AND lab_result_obs.obs_datetime <= '2022-07-31 23:59:59'
              AND lab_result_obs.person_id IN (#{ids})
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
