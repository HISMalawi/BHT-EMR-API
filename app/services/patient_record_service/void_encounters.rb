# app/services/patient_record_service/void_encounters.rb
# frozen_string_literal: true

module PatientRecordService
  class VoidEncounters < BaseSaver
    def void_encounters(record)
      data = record.dig(:void_encounters)
      return false unless data.is_a?(Array) && data.any?

      voided_count = 0
      errors = []

      data.each do |void_request|
        encounter_id = void_request[:id]
        reason = void_request[:reason]

        unless encounter_id.present? && reason.present?
          errors << { id: encounter_id, error: "Missing encounter_id or reason" }
          next
        end

        begin
          encounter = Encounter.find(encounter_id)
          encounter_service.void(encounter, reason)
          voided_count += 1
        rescue ActiveRecord::RecordNotFound => e
          errors << { id: encounter_id, error: "Encounter not found: #{e.message}" }
          log_error("Failed to void encounter #{encounter_id}", e)
        rescue StandardError => e
          errors << { id: encounter_id, error: e.message }
          log_error("Failed to void encounter #{encounter_id}", e)
        end
      end

      # Log summary if there were errors
      if errors.any?
        Rails.logger.error("Failed to void #{errors.size}/#{data.size} encounters. Errors: #{errors.to_json}")
      end

      return false if errors.any?

      voided_count > 0
    end

    private

    def encounter_service
      @encounter_service ||= EncounterService.new
    end
  end
end
