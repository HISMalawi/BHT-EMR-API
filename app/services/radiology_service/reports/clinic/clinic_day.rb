# frozen_string_literal: true

module RadiologyService
  module Reports
    module Clinic
      # This class is used to generate the daily clinic report.
      class ClinicDay
        ENCOUNTERS = ['Radiology Examination', 'Appointment'].freeze

        def initialize(start_date:, end_date:)
          @start_date = start_date.to_date.strftime('%Y-%m-%d 00:00:00')
          @end_date = end_date.to_date.strftime('%Y-%m-%d 23:59:59')
          @program_id = Program.find_by(name: 'RADIOLOGY PROGRAM').id
        end

        def data
          report
        end

        private

        def report
          ActiveRecord::Base.connection.select_all <<~SQL
            SELECT et.name, COALESCE(individual_clinic.total_encounters, 0) AS me, COALESCE(clinic.total_encounters, 0) AS clinic
            FROM encounter_type et
            LEFT JOIN (
              SELECT e.encounter_type, count(*) as total_encounters
              FROM encounter e
              WHERE e.encounter_datetime BETWEEN '#{@start_date}' AND '#{@end_date}'
              AND e.voided = 0
              AND e.program_id = #{@program_id}
              GROUP BY e.encounter_type
            ) AS clinic ON clinic.encounter_type = et.encounter_type_id
            LEFT JOIN (
              SELECT e.encounter_type, count(*) as total_encounters
              FROM encounter e
              WHERE e.encounter_datetime BETWEEN '#{@start_date}' AND '#{@end_date}'
              AND e.voided = 0
              AND e.program_id = #{@program_id}
              AND e.provider_id = #{User.current.id}
              GROUP BY e.encounter_type
            ) AS individual_clinic ON individual_clinic.encounter_type = et.encounter_type_id
            WHERE et.retired = 0
            AND et.encounter_type_id IN ('#{encounter_type_ids.join("','")}')
          SQL
        end

        def encounter_type_ids
          EncounterType.where(name: ENCOUNTERS).pluck(:encounter_type_id)
        end
      end
    end
  end
end
