# frozen_string_literal: true

module AetcService
  module Reports
    module Clinic
      # This report gives a list of areas with patients with a specific diagnosis
      class DiagnosisSpecificReport
        include ModelUtils

        # @return [String] the start date of the report
        attr_reader :start_date

        # @return [String] the end date of the report
        attr_reader :end_date

        # @return [String] the diagnosis for the report
        attr_reader :diagnosis

        # Initializes a new instance of the DiagnosisSpecificReport class
        #
        # @param start_date [DateTime] the start date of the report
        # @param end_date [DateTime] the end date of the report
        # @param diagnosis [Array<String>] the diagnosis for the report
        def initialize(start_date:, end_date:, **kwargs)
          @start_date = start_date.to_date.beginning_of_day
          @end_date = end_date.to_date.end_of_day
          @diagnosis = JSON.parse(kwargs[:diagnosis]).map { |d| "'#{d}'" }
        end

        # Fetches the report data
        #
        # @return [Array<Hash>] the report data
        def fetch_report
          return [] if diagnosis.blank?

          process_data || []
        end

        private

        # Gets the report data from the database
        #
        # @return [Array<Hash>] the report data
        def data
          ActiveRecord::Base.connection.select_all <<~SQL
            SELECT pa.county_district as address, GROUP_CONCAT(DISTINCT e.patient_id) as patient_ids
            FROM obs o
            INNER JOIN encounter e ON e.encounter_id = o.encounter_id
                    AND e.voided = 0
                    AND e.program_id = #{program('AETC PROGRAM').program_id}
                    AND e.encounter_datetime >= '#{start_date}' AND e.encounter_datetime <= '#{end_date}'
                    AND e.encounter_type = #{encounter_type('OUTPATIENT DIAGNOSIS').encounter_type_id}
            INNER JOIN patient p ON p.patient_id = e.patient_id AND p.voided = 0
            INNER JOIN person_address pa ON pa.person_id = p.patient_id AND pa.voided = 0
            WHERE o.concept_id IN (#{concept('PRIMARY DIAGNOSIS').concept_id}, #{concept('SECONDARY DIAGNOSIS').concept_id})
                    AND o.voided = 0
                    AND o.value_coded IN (SELECT concept_id FROM concept_name WHERE name IN (#{diagnosis.join(',')}))
                    AND o.obs_datetime >= '#{start_date}' AND o.obs_datetime <= '#{end_date}'
            GROUP BY pa.county_district
          SQL
        end

        # Processes the report data
        #
        # @return [Array<Hash>] the processed report data
        def process_data
          data.map do |d|
            {
              address: d['address'],
              patient_ids: d['patient_ids'].split(',')
            }
          end
        end
      end
    end
  end
end
