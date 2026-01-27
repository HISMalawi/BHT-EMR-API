# app/services/patient_record_service/outcome_saver.rb
# frozen_string_literal: true

module PatientRecordService
  class OutcomeSaver < BaseSaver
    ENCOUNTER_TYPE_MAPPING = SavePatientRecordService::ENCOUNTER_TYPE_MAPPING

    def save_outcome(patient_id, record)
      outcome = record.dig(:outCome, :unsaved)
      return false unless outcome.present?

      begin
        outcomes_array = outcome.is_a?(Array) ? outcome : [outcome]
        outcomes_array.each do |out_come|
          next unless out_come.present?

          encounter_type = EncounterType.find_by_name(ENCOUNTER_TYPE_MAPPING[:patient_outcome])
          encounter_id = create_encounter(patient_id, encounter_type.id, record)
          encounter = Encounter.find(encounter_id)

          unless encounter.type.name == 'PATIENT OUTCOME'
            Rails.logger.warn("Unexpected encounter type: #{encounter.type.name} for encounter ##{encounter.encounter_id}")
            next
          end

          if out_come.is_a?(ActionController::Parameters)
            out_come = out_come.permit!.to_h
          end

          if out_come[:value_text].is_a?(ActionController::Parameters)
            out_come[:value_text] = out_come[:value_text].permit!.to_h.to_json
          end

          out_come[:person_id] = patient_id if out_come[:person_id].blank?
          out_come[:location_id] ||= User.current.location_id

          observation_service.create_observation(encounter, out_come)
        end
        true
      rescue StandardError => e
        log_error("Failed to create patient outcome", e)
        raise # Re-raise if you want the transaction to rollback
      end
    end
  end
end