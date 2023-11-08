# frozen_string_literal: true

module AetcService
  module Reports
    module Clinic
      # Generates referral report
      class ReferralReport
        include ModelUtils
        def initialize(start_date:, end_date:, **_kwargs)
          @start_date = start_date
          @end_date = end_date
        end

        def fetch_report
          process_data
        end

        private

        def data
          ActiveRecord::Base.connection.select_all <<~SQL
            SELECT l.name AS location, GROUP_CONCAT(DISTINCT p.patient_id) AS patients
            FROM obs o
            INNER JOIN encounter e ON e.encounter_id = o.encounter_id AND e.voided = 0 AND e.program_id = #{program('AETC PROGRAM').program_id} AND e.encounter_datetime >= '#{@start_date}' AND e.encounter_datetime <= '#{@end_date}'
            INNER JOIN patient p ON p.patient_id = e.patient_id AND p.voided = 0
            INNER JOIN person pe ON pe.person_id = p.patient_id AND pe.voided = 0
            INNER JOIN location l ON l.location_id = o.value_text AND l.retired = 0
            WHERE o.voided = 0 AND o.concept_id = #{concept('Referred from').concept_id} AND o.obs_datetime >= '#{@start_date}' AND o.obs_datetime <= '#{@end_date}'
            GROUP BY l.name
          SQL
        end

        def process_data
          data.map do |row|
            {
              location: row['location'],
              patients: row['patients'].split(',')
            }
          end
        end
      end
    end
  end
end
