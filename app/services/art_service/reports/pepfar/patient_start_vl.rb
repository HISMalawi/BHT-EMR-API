# frozen_string_literal: true

module ARTService
  module Reports
    module Pepfar
      # this module returns all the patient records on when
      # when the patient started ART
      # plus the last viral load result
      class PatientStartVL
        def get_patients_last_vl_and_latest_result(patient_ids, _end_date)
          ids = patient_ids.push(0).join(',')
          ActiveRecord::Base.connection.select_all <<~SQL
            SELECT p.person_id AS patient_id,
            patient_start_date(p.person_id) AS art_start_date,
            p.birthdate AS birthdate,
            p.gender,
            pi.identifier
            FROM person p
            LEFT JOIN patient_identifier pi ON pi.patient_id = p.person_id AND pi.voided = 0 AND pi.identifier_type = 4
            WHERE p.voided = 0
            AND p.person_id IN (#{ids})
          SQL
        end
      end
    end
  end
end
