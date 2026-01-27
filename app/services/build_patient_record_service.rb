# frozen_string_literal: true

module BuildPatientRecordService
  class << self
    include ModelUtils
    include BuildPatientRecordService::ObservationExtractor
    include BuildPatientRecordService::LabOrderService
    include BuildPatientRecordService::DrugService
    include BuildPatientRecordService::EncounterService
    include BuildPatientRecordService::GuardianService
    include BuildPatientRecordService::PatientIdentifierService
    include BuildPatientRecordService::PersonInformationBuilder
    include BuildPatientRecordService::ScreeningService
    include BuildPatientRecordService::VaccineService
    include BuildPatientRecordService::VisitService

    # Main entry point for building patient records
    def build_patient_record(patient_id)
      validate_patient_id(patient_id)
      
      patient = find_patient(patient_id)
      return handle_patient_not_found(patient_id) unless patient

      build_complete_record(patient)
    rescue StandardError => e
      handle_error(e, patient_id)
    end


    def validate_patient_id(patient_id)
      raise ArgumentError, "Patient ID cannot be nil or empty" if patient_id.blank?
    end

    def find_patient(patient_id)
      Patient.find_by(patient_id: patient_id)
    end

    def handle_patient_not_found(patient_id)
      Rails.logger.warn("Patient not found: #{patient_id}")
      nil
    end

    def build_complete_record(patient)
      person = patient.person
      latest_encounter = find_latest_encounter(patient.patient_id)
      
      {
        **build_basic_info(patient, latest_encounter),
        **build_personal_data(person, patient),
        **build_clinical_data(patient.patient_id),
        **build_administrative_data(patient),
        **build_status_fields
      }
    end

    def find_latest_encounter(patient_id)
      Encounter.where(patient_id: patient_id)
               .order(encounter_datetime: :desc)
               .first
    end

    def build_basic_info(patient, latest_encounter)
      {
        patientID: patient.patient_id,
        ID: patient_identifier(patient, 3),
        NcdID: patient_identifier(patient, 31),
        program_id: '',
        provider_id: '',
        patient_identifiers: patient.patient_identifiers.as_json,
        location_id: latest_encounter&.location_id,
        encounter_datetime: latest_encounter&.encounter_datetime,
        encounter_date_changed: latest_encounter&.date_changed,
        sync_status: ''
      }
    end

    def build_personal_data(person, patient)
      name = person&.names&.first
      address = person&.addresses&.first

      {
        personInformation: build(person, name, address, patient),
        guardianInformation: build_guardian_data(patient.patient_id),
        otherPersonInformation: build_other_person_info,
        vaccineSchedule: safe_get_vaccine_schedule(person)
      }
    end

    def build_clinical_data(patient_id)
      {
        birthRegistration: build_observation_data(patient_id, 'REGISTRATION'),
        vitals: build_observation_data(patient_id, 'VITALS'),
        vaccineAdministration: build_vaccine_administration_data(patient_id),
        appointments: build_observation_data(patient_id, 'APPOINTMENT'),
        diagnosis: build_observation_data(patient_id, 'DIAGNOSIS'),
        screening: build_observation_data(patient_id, 'SCREENING'),
        substanceAbuse: build_observation_data(patient_id, 'ASSESSMENT'),
        labOrders: build_lab_orders_data(patient_id),
        MedicationOrder: build_medication_data(patient_id),
        outCome: build_empty_data_structure,
        notes: build_observation_data(patient_id, 'NOTES'),
        allergies: build_observation_data(patient_id, 'MEDICAL HISTORY'),
        observations: build_all_observations(patient_id, allowed_encounter_types = nil, status = "saved")
      }
    end

    def build_administrative_data(patient)
      {
        dispensations: build_dispensations_data(patient),
        visits: safe_get_visits(patient),
        activePrograms: fetch_active_programs(patient.patient_id)
      }
    end

    def build_status_fields
      {
        saveStatusPersonInformation: '',
        saveStatusGuardianInformation: '',
        saveStatusBirthRegistration: ''
      }
    end

    # Helper methods for building specific data structures
    def build_observation_data(patient_id, encounter_type)
      {
        saved: safe_extract_observations(patient_id, safe_find_encounter_type(encounter_type)),
        unsaved: []
      }
    end

    def build_guardian_data(patient_id)
      {
        saved: safe_get_guardians(patient_id),
        unsaved: []
      }
    end

    def build_other_person_info
      {
        nationalID: '',
        birthID: '',
        relationshipID: ''
      }
    end

    def build_vaccine_administration_data(patient_id)
      {
        orders: [],
        obs: [],
        voided: []
      }
    end

    def build_screening_data(patient_id)
      {
        saved: safe_get_screening_data(patient_id),
        unsaved: []
      }
    end

    def build_lab_orders_data(patient_id)
      {
        saved: safe_get_lab_orders(patient_id),
        unsaved: [],
        voided: []
      }
    end

    def build_medication_data(patient_id)
      {
        saved: get_client_drug_orders(patient_id),
        unsaved: []
      }
    end

    def build_empty_data_structure
      {
        saved: [],
        unsaved: []
      }
    end

    def build_dispensations_data(patient)
      {
        saved: PatientService.new.find_program_drug_orders_awaiting_dispensation(patient, Date.today).as_json,
        unsaved: []
      }
    end


    def fetch_active_programs(patient_id)
      PatientProgram.where(patient_id: patient_id).to_a.map(&:as_json)
    end

    def handle_error(error, patient_id)
      Rails.logger.error("Error in build_patient_record for patient #{patient_id}: #{error.message}")
      Rails.logger.error(error.backtrace.join("\n"))
      
      # You might want to notify an error tracking service here
      # ErrorTrackingService.notify(error, { patient_id: patient_id })
      
      nil
    end
  end
end