# frozen_string_literal: true
module BuildPatientRecordService

  module ScreeningService
    include ModelUtils

      def safe_get_screening_data(patient_id)
        begin
          screening_type = EncounterService.safe_find_encounter_type('SCREENING')
          return [] unless screening_type
          
          regular_screening = ObservationExtractor.safe_extract_observations(patient_id, screening_type, nil, true) || []
          cvd_screening = ObservationExtractor.safe_extract_observations(patient_id, screening_type, 
                                                  { concept_id: safe_concept_name_to_id('CVD') }) || []
          
          [regular_screening + cvd_screening].flatten.compact
        rescue StandardError => e
          Rails.logger.error("Error getting screening data for patient #{patient_id}: #{e.message}")
          []
        end
      end
      
      private

      def safe_concept_name_to_id(name)
        concept_name_to_id(name)
      rescue StandardError => e
        Rails.logger.error("Error converting concept name '#{name}' to ID: #{e.message}")
        nil
      end
    
  end
end