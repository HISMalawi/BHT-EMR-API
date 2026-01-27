# app/services/patient_record_service/observation_saver.rb
# frozen_string_literal: true

module PatientRecordService
  class ObservationSaver < BaseSaver
    ENCOUNTER_TYPE_MAPPING = SavePatientRecordService::ENCOUNTER_TYPE_MAPPING

    def save_notes_and_pharmalogical_notes(patient_id, record)
      save_observations_with_encounter(patient_id, record, {
        data_key: :notes,
        encounter_type: :notes,
        expected_type: 'NOTES',
        error_message: 'notes'
      })
    end

    def save_allergies(patient_id, record)
      save_observations_with_encounter(patient_id, record, {
        data_key: :allergies,
        encounter_type: :allergies,
        expected_type: 'MEDICAL HISTORY',
        error_message: 'allergies'
      })
    end

   def save_all_observations(patient_id, record)
    data = record.dig(:observations)
    return false unless data&.any?

    # Check if there are any items with "unsaved" status
    unsaved_items = data.select { |item| item.present? && item[:status] == "unsaved" && item[:obs]&.any? }
    return false if unsaved_items.empty?

    begin
      ActiveRecord::Base.transaction do
        unsaved_items.each do |item|
          encounter_type = EncounterType.find_by_encounter_type_id(item[:encounter_type])
          next unless encounter_type

          encounter_id = create_encounter(patient_id, encounter_type.id, record)
          encounter = Encounter.find(encounter_id)
          item[:obs].map do |archetype|
            archetype[:location_id] = record[:location_id]
            params = archetype.respond_to?(:permit!) ? archetype.permit! : archetype
            observation_service.create_observation(encounter, params)
          end
        end
      end
      return true
    rescue StandardError => e
      log_error("Error saving observations", e)
      return false  
    end
  end

    private

    def save_observations_with_encounter(patient_id, record, options)
      data = record.dig(options[:data_key], :unsaved)
      return false unless data&.any?

      begin
        ActiveRecord::Base.transaction do
          data.each do |item|
            next unless item.present?

            encounter_type = EncounterType.find_by_name(ENCOUNTER_TYPE_MAPPING[options[:encounter_type]])
            encounter_id = create_encounter(patient_id, encounter_type.id, record)
            encounter = Encounter.find(encounter_id)

            unless encounter.type.name == options[:expected_type]
              Rails.logger.warn("Unexpected encounter type: #{encounter.type.name} for encounter ##{encounter.encounter_id}")
              next
            end

            if item.is_a?(ActionController::Parameters)
              item = item.permit!.to_h
            end

            if item[:value_text].is_a?(ActionController::Parameters) || item[:value_text].is_a?(Hash)
              item[:value_text] = item[:value_text].to_json
            end

            item[:person_id] = patient_id if item[:person_id].blank?
            item[:location_id] ||= User.current.location_id

            observation_service.create_observation(encounter, item)
          end
          return true
        end
      rescue StandardError => e
        log_error("Failed to save #{options[:error_message]}", e)
      end
    end
  end
end