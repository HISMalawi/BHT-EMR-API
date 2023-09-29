# frozen_string_literal: true

module AetcService
  module Clinic
    # A hash of encounter types and their display names
    class DashboardStats
      ENCOUNTERS = [
        'SOCIAL HISTORY',
        'PATIENT REGISTRATION',
        'VITALS',
        'PRESENTING COMPLAINTS',
        'OUTPATIENT DIAGNOSIS',
        'PRESCRIPTION',
        'DISPENSING',
        'TREATMENT'
      ].freeze

      # Initializes a new instance of the DashboardStats class
      #
      # @param start_date [Date] The start date to generate the report for
      # @param end_date [Date] The end date to limit the result
      def initialize(start_date, end_date)
        @program = Program.find_by_name 'AETC PROGRAM'
        @start_date = start_date.to_date.beginning_of_day
        @end_date = end_date.to_date.end_of_day
      end

      # Generates a report of dashboard stats
      #
      # @return [Hash] A hash of dashboard stats
      def find_report
        patient_providers_encounters
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
            WHERE e.encounter_datetime => '#{@start_date}' AND e.encounter_datetime <= '#{@end_date}'
            AND e.voided = 0
            AND e.program_id = #{@program.id}
            GROUP BY e.encounter_type
          ) AS clinic ON clinic.encounter_type = et.encounter_type_id
          LEFT JOIN (
            SELECT e.encounter_type, count(*) as total_encounters
            FROM encounter e
            WHERE e.encounter_datetime BETWEEN '#{@start_date}' AND '#{@end_date}'
            AND e.voided = 0
            AND e.program_id = #{@program.id}
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
