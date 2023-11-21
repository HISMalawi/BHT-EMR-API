# frozen_string_literal: true

module AetcService
  module Reports
    module Clinic
      # A hash of encounter types and their display names
      class DashboardStats
        ENCOUNTERS = [
          'SOCIAL HISTORY',
          'PATIENT REGISTRATION',
          'VITALS',
          'PRESENTING COMPLAINTS',
          'OUTPATIENT DIAGNOSIS',
          'TREATMENT',
          'DISPENSING'
        ].freeze

        # Initializes a new instance of the DashboardStats class
        #
        # @param start_date [Date] The start date to generate the report for
        # @param end_date [Date] The end date to limit the result
        def initialize(start_date:, end_date:, **_kwargs)
          @program = Program.find_by_name 'AETC PROGRAM'
          @start_date = start_date.to_date.beginning_of_day.strftime('%Y-%m-%d %H:%M:%S')
          @end_date = end_date.to_date.end_of_day.strftime('%Y-%m-%d %H:%M:%S')
        end

        # Generates a report of dashboard stats
        #
        # @return [Hash] A hash of dashboard stats
        def fetch_report
          {
            top: {
              registered_today: registered_today('New patient'),
              returning_today: registered_today('Revisiting'),
              referred_today: registered_today('Referral')
            },
            bottom: patient_providers_encounters
          }
        end

        private

        # Get the patient providers encounter for the specified date
        #
        # @return [Array] An array of encounters
        def patient_providers_encounters
          ActiveRecord::Base.connection.select_all <<~SQL
            SELECT et.name, COALESCE(individual_clinic.total_encounters, 0) AS me, COALESCE(clinic.total_encounters, 0) AS facility, COALESCE(clinic.total_encounters, 0) + COALESCE(individual_clinic.total_encounters, 0) AS total
            FROM encounter_type et
            LEFT JOIN (
              SELECT e.encounter_type, count(*) as total_encounters
              FROM encounter e
              WHERE e.encounter_datetime >= ('#{@start_date}') AND e.encounter_datetime <= ('#{@end_date}')
              AND e.voided = 0
              AND e.program_id = #{@program.id}
              AND e.provider_id != #{User.current.person.id}
              GROUP BY e.encounter_type
            ) AS clinic ON clinic.encounter_type = et.encounter_type_id
            LEFT JOIN (
              SELECT e.encounter_type, count(*) as total_encounters
              FROM encounter e
              WHERE e.encounter_datetime >= ('#{@start_date}') AND e.encounter_datetime <= ('#{@end_date}')
              AND e.voided = 0
              AND e.program_id = #{@program.id}
              AND e.provider_id = #{User.current.person.id}
              GROUP BY e.encounter_type
            ) AS individual_clinic ON individual_clinic.encounter_type = et.encounter_type_id
            WHERE et.retired = 0
            AND et.encounter_type_id IN ('#{encounter_type_ids.join("','")}')
          SQL
        end

        def registered_today(visit_type)
          type = EncounterType.find_by_name 'Patient registration'
          concept = ConceptName.find_by_name 'Type of visit'
          value_coded = ConceptName.find_by_name visit_type

          encounter_ids = Encounter.where('encounter_datetime BETWEEN ? AND ?
            AND encounter_type = ?', *TimeUtils.day_bounds(@start_date), type.id).map(&:encounter_id)

          Observation.where('encounter_id IN(?) AND concept_id = ? AND value_coded = ?',
                            encounter_ids, concept.concept_id, value_coded.concept_id).group(:person_id).length
        end

        def encounter_type_ids
          EncounterType.where(name: ENCOUNTERS).pluck(:encounter_type_id)
        end
      end
    end
  end
end
