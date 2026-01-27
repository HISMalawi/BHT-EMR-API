# app/services/save_patient_record_service.rb
# frozen_string_literal: true

class SavePatientRecordService
  # Defines expected required fields and their keys within the record hash.
  RequiredFields = Struct.new(:program_id, :provider_id, :location_id, :encounter_datetime)
  # Defines expected ID fields and their keys within the record hash.
  PatientIds = Struct.new(:national_id, :ichis_id, :birth_id)

  ENCOUNTER_TYPE_MAPPING = {
    vitals: 'VITALS',
    diagnosis: 'DIAGNOSIS',
    substance_abuse: 'ASSESSMENT',
    screening: 'SCREENING',
    lab_orders: 'LAB ORDERS',
    lab_results: 'LAB RESULTS',
    family_medical_history: 'FAMILY MEDICAL HISTORY',
    complications: 'COMPLICATIONS',
    tb_reception: 'TB RECEPTION',
    hiv_status_at_enrollment: 'HIV STATUS AT ENROLLMENT',
    medical_history: 'MEDICAL HISTORY',
    patient_registration: 'PATIENT REGISTRATION',
    patient_outcome: 'PATIENT OUTCOME',
    treatment: 'TREATMENT',
    notes: 'NOTES',
    allergies: 'MEDICAL HISTORY'
  }.freeze

  def create_patient_record(record)
    # 1. Extract and Validate Initial Data
    required_fields = extract_required_fields(record)
    return "required fields missing" unless required_fields_present?(required_fields)

    ids = extract_patient_ids(record)

    # 2. Initialize Service Managers
    managers = initialize_managers

    # 3. Save Person Information and Get Patient ID
    identity_data = managers[:identity_manager].save_person_information(record)
    patient_id = identity_data[:patient_id]
    return "Patient ID not found" unless patient_id

    # 4. Initial ID Validation
    unless managers[:identity_manager].validate_ids(ids.national_id, ids.birth_id, ids.ichis_id)
      return "ID Validation Failed"
    end
   
    # 5. Execute Operations within Transaction
    overall_sync_status = 'synced'
    operation_results = {} # To store success/failure of each operation

    begin
      ActiveRecord::Base.transaction do
        operation_results = execute_patient_operations(patient_id, record, managers)

        # Determine overall status based on operation_results (assuming any false means partial_failed)
        if operation_results.value?(false)
          failed_ops_list = operation_results.select { |_k, v| v == false }.keys.join(', ')
          Rails.logger.error("Overall record saving for patient #{patient_id} had failures in: #{failed_ops_list}")
          overall_sync_status = 'partial_failed'
          # If you want to force a rollback on *any* failure among these, uncomment the line below:
          # raise ActiveRecord::Rollback
        else
          Rails.logger.info("All sub-operations successfully processed for patient #{patient_id}.")
        end
      end # End of ActiveRecord::Base.transaction block
    rescue StandardError => e
      Rails.logger.error("An unhandled error occurred during patient record saving for patient #{patient_id}: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      overall_sync_status = 'failed'
      raise # Re-raise to ensure the transaction is rolled back
    end

    # 6. Build and Save Final Patient Record
    build_and_save_patient_record(patient_id, record, operation_results, overall_sync_status)
  end

  private

  def extract_required_fields(record)
    RequiredFields.new(
      program_id: record.dig(:program_id),
      provider_id: record.dig(:provider_id),
      location_id: record.dig(:location_id),
      encounter_datetime: record.dig(:encounter_datetime)
    )
  end

  def required_fields_present?(required_fields)
    required_fields.to_h.values.all? { |value| value.present? } 
  end

  def extract_patient_ids(record)
    PatientIds.new(
      national_id: record.dig(:otherPersonInformation, :nationalID),
      ichis_id: record.dig(:otherPersonInformation, :ichisID),
      birth_id: record.dig(:otherPersonInformation, :birthID)
    )
  end

  def initialize_managers
    {
      identity_manager: PatientRecordService::PatientIdentityManager.new,
      guardian_manager: PatientRecordService::GuardianManager.new,
      enrollment_manager: PatientRecordService::PatientEnrollmentManager.new,
      clinical_data_saver: PatientRecordService::ClinicalDataSaver.new,
      lab_data_manager: PatientRecordService::LabDataManager.new,
      vaccine_manager: PatientRecordService::VaccineManager.new,
      appointment_manager: PatientRecordService::AppointmentManager.new,
      sms_manager: PatientRecordService::SmsManager.new,
      outcome_saver: PatientRecordService::OutcomeSaver.new,
      medication_order_saver: PatientRecordService::MedicationOrderSaver.new,
      dispensation_saver: PatientRecordService::DispensationSaver.new,
      observation_saver: PatientRecordService::ObservationSaver.new
    }
  end

  def execute_patient_operations(patient_id, record, managers)
    {
      update_person_info: managers[:identity_manager].update_person_information(patient_id, record),
      manage_guardian: managers[:guardian_manager].manage_guardian(patient_id, record),
      # enroll_program: managers[:enrollment_manager].enroll_program(patient_id, record),
      save_birthday_data: managers[:clinical_data_saver].save_birthday_data(patient_id, record),
      save_vitals_data: managers[:clinical_data_saver].save_vitals_data(patient_id, record),
      save_diagnosis_data: managers[:clinical_data_saver].save_diagnosis_data(patient_id, record),
      save_enrollment_data: managers[:clinical_data_saver].save_enrollment_data(patient_id, record),
      save_substance_abuse_data: managers[:clinical_data_saver].save_substance_abuse_data(patient_id, record),
      save_screening_data: managers[:clinical_data_saver].save_screening_data(patient_id, record),
      save_lab_orders_data: managers[:lab_data_manager].save_lab_orders_data(patient_id, record),
      save_lab_results_data: managers[:lab_data_manager].save_lab_results_data(patient_id, record),
      void_lab_order: managers[:lab_data_manager].void_lab_order(patient_id, record),
      save_vaccines: managers[:vaccine_manager].save_vaccines(patient_id, record),
      save_appointments: managers[:appointment_manager].save_appointments(patient_id, record),
      send_sms: managers[:sms_manager].send_sms(patient_id, record),
      void_vaccine: managers[:vaccine_manager].void_vaccine(patient_id, record),
      save_outcome: managers[:outcome_saver].save_outcome(patient_id, record),
      save_medication_order: managers[:medication_order_saver].save_medication_order(patient_id, record),
      create_ncd_identifier: managers[:identity_manager].create_ncd_identifier(patient_id, record),
      save_notes_and_pharmalogical_notes: managers[:observation_saver].save_notes_and_pharmalogical_notes(patient_id, record),
      save_allergies: managers[:observation_saver].save_allergies(patient_id, record),
      save_dispensation_data: managers[:medication_order_saver].save_dispensation_data(patient_id, record),
      save_all_observations: managers[:observation_saver].save_all_observations(patient_id, record)
    }
  end

  def build_and_save_patient_record(patient_id, patient_data, operation_results, overall_sync_status)

    # Fetch patient and encounter details once
    patient = BuildPatientRecordService.find_patient(patient_id)
    person = patient&.person
    latest_encounter = BuildPatientRecordService.find_latest_encounter(patient_id)

    # Always set these base attributes
    patient_data[:encounter_datetime] = latest_encounter&.encounter_datetime
    patient_data[:location_id] = latest_encounter&.location_id
    patient_data[:ID] = BuildPatientRecordService.patient_identifier(patient, 3) 
    patient_data[:patientID] = patient_id
    patient_data[:NcdID] = BuildPatientRecordService.patient_identifier(patient, 31)
    patient_data[:sync_status] = overall_sync_status 
    patient_data[:otherPersonInformation] = BuildPatientRecordService.build_other_person_info 
    patient_data[:visits]  = BuildPatientRecordService.safe_get_visits(patient)
    patient_data[:activePrograms]  = BuildPatientRecordService.fetch_active_programs(patient.patient_id)
    
    # Update specific sections based on successful operations
    operation_results.each do |key, success|
      next unless success

      case key
      when :update_person_info
        name = person&.names&.first
        address = person&.addresses&.first
        patient_data[:personInformation] = BuildPatientRecordService.build(person, name, address, patient)
      when :manage_guardian
        patient_data[:guardianInformation] = BuildPatientRecordService.build_guardian_data(patient_id)
      when :enroll_program
        patient_data[:activePrograms] = BuildPatientRecordService.fetch_active_programs(patient_id)
      when :save_birthday_data
        patient_data[:birthRegistration] = BuildPatientRecordService.build_observation_data(patient_id, 'REGISTRATION')
      when :save_vitals_data
        patient_data[:vitals] = BuildPatientRecordService.build_observation_data(patient_id, 'VITALS')
      when :save_diagnosis_data
        patient_data[:diagnosis] = BuildPatientRecordService.build_observation_data(patient_id, 'DIAGNOSIS')
      when :save_substance_abuse_data
        patient_data[:substanceAbuse] = BuildPatientRecordService.build_observation_data(patient_id, 'ASSESSMENT')
      when :save_screening_data
        patient_data[:screening] = BuildPatientRecordService.build_screening_data(patient_id)
      when :save_lab_orders_data, :save_lab_results_data, :void_lab_order
        patient_data[:labOrders] = BuildPatientRecordService.build_lab_orders_data(patient_id)
      when :save_vaccines, :void_vaccine
        patient_data[:vaccineAdministration] = BuildPatientRecordService.build_vaccine_administration_data(patient_id)
        patient_data[:vaccineSchedule] = BuildPatientRecordService.safe_get_vaccine_schedule(person)
      when :save_appointments
        patient_data[:appointments] = BuildPatientRecordService.build_observation_data(patient_id, 'APPOINTMENT')
      when :save_outcome
        patient_data[:outCome] = BuildPatientRecordService.build_empty_data_structure 
      when :save_medication_order, :save_dispensation_data
        patient_data[:MedicationOrder] = BuildPatientRecordService.build_medication_data(patient_id)
        # patient_data[:dispensations] = BuildPatientRecordService.build_dispensations_data(patient)
      when :create_ncd_identifier
        patient_data[:NcdID] = BuildPatientRecordService.patient_identifier(patient, 31)
      when :save_notes_and_pharmalogical_notes
        patient_data[:notes] = BuildPatientRecordService.build_observation_data(patient_id, 'NOTES')
      when :save_allergies
        patient_data[:allergies] = BuildPatientRecordService.build_observation_data(patient_id, 'MEDICAL HISTORY')
      when :save_all_observations
        allowed_encounter_types = patient_data[:observations]
                                            .select { |e| e[:status] == "unsaved" }
                                            .map { |e| e[:encounter_type] }
                                            .uniq
        
        allowed_encounter_types = allowed_encounter_types.compact
        if allowed_encounter_types.empty? ||allowed_encounter_types.nil? 
          break 
        end

         original_observations_map = patient_data[:observations]
                                  .each_with_object({}) do |obs, hash|
                                    hash[obs[:encounter_type]] = obs
                                  end

        new_observations = BuildPatientRecordService.build_all_observations(patient_id, allowed_encounter_types)
        updated_observations_hash = original_observations_map.merge(new_observations.index_by { |obs| obs[:encounter_type] })
        patient_data[:observations] = updated_observations_hash.values.as_json

      end
    end
    
    # Return the patient data as JSON
    patient_data.as_json
  end
end