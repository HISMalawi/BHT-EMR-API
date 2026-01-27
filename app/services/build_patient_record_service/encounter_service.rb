# frozen_string_literal: true
module BuildPatientRecordService
  module EncounterService
      def safe_find_encounter_type(name)
        EncounterType.find_by_name(name)&.id
      rescue StandardError => e
        Rails.logger.error("Error finding encounter type '#{name}': #{e.message}")
        nil
      end
  end
end