# app/services/patient_record_service/clinical_data_saver.rb
# frozen_string_literal: true

module PatientRecordService
  class ClinicalDataSaver < BaseSaver
    # Map for encounter types (can be shared from SavePatientRecordService or a dedicated constant)
    ENCOUNTER_TYPE_MAPPING = SavePatientRecordService::ENCOUNTER_TYPE_MAPPING

    def save_birthday_data(patient_id, record)
      return false unless record[:saveStatusBirthRegistration] == 'pending'
      return false unless record[:birthRegistration].present? && record[:birthRegistration].any?

      begin
        encounter_id = create_encounter(patient_id, 5, record)
        save_obs(
          encounter_id: encounter_id,
          observations: record[:birthRegistration],
          location_id: record[:location_id]
        )
        record[:saveStatusBirthRegistration] = 'complete'
        true
      rescue StandardError => e
        log_error("Failed to save birth information", e)
      end
    end

    def save_vitals_data(patient_id, record)
      save_clinical_data(:vitals, patient_id, record)
    end

    def save_diagnosis_data(patient_id, record)
      save_clinical_data(:diagnosis, patient_id, record)
    end

    def save_enrollment_data(patient_id, record)
      unsaved = record.dig(:NCDEnrollment, :unsaved)
      return false unless unsaved.present?

      {
        familyMedicalHistory: :familyMedicalHistory,
        patientRegistration: :patientRegistration,
        complications: :complications,
        hivStatusAtEnrollment: :hivStatusAtEnrollment,
        tbReception: :tbReception,
        medicalHistory: :medicalHistory
      }.each do |key, data_type|
        next unless unsaved[key].present?
        pass_save_data(data_type, unsaved[key], patient_id, record)
      end
      record[:NCDEnrollment][:unsaved] = {}
      return true
    end

    def save_substance_abuse_data(patient_id, record)
      save_clinical_data(:substance_abuse, patient_id, record)
    end

    def save_screening_data(patient_id, record)
      save_clinical_data(:screening, patient_id, record)
    end

    private

    def save_clinical_data(data_type, patient_id, record)
      data_key = data_type.to_s.underscore.to_sym
      unsaved_data = record.dig(data_type, :unsaved)
      return false unless unsaved_data&.any?

      if data_type == :diagnosis && record.dig(:program_id) == 32
        unsaved_data.each do |item|
          if item["value_coded"] == 6409 || item["value_coded"] == 6410
            FhirService.sendConfirmedDiagnosisToMediator(patient_id, "Diabetes")
          end
          if item["value_coded"] == 903
            FhirService.sendConfirmedDiagnosisToMediator(patient_id, "Hypertension")
          end
        end
      end

      if save_observations(data_key, unsaved_data, patient_id, record)
        record[data_type][:unsaved] = []
        return true
      end
    end

    def pass_save_data(data_type, unsaved_data, patient_id, record)
      return unless unsaved_data&.any?

      data_key = data_type.to_s.underscore.to_sym
      save_observations(data_key, unsaved_data, patient_id, record)
    end

    def save_observations(data_key, observations, patient_id, record)
      encounter_type_name = ENCOUNTER_TYPE_MAPPING[data_key]
      unless encounter_type_name
        log_error("No encounter type mapped for #{data_key}", StandardError.new("Missing mapping"))
        return false
      end

      encounter_type = EncounterType.find_by_name(encounter_type_name)
      unless encounter_type
        log_error("EncounterType not found for #{encounter_type_name}", StandardError.new("Missing encounter type"))
        return false
      end

      begin
        encounter_id = create_encounter(patient_id, encounter_type.id, record)
        save_obs(
          encounter_id: encounter_id,
          observations: observations,
          location_id: record[:location_id]
        )
        true
      rescue StandardError => e
        log_error("Failed to save #{data_key} observations", e)
        false
      end
    end
  end
end