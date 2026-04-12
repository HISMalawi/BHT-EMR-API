# app/services/save_patient_record_service.rb
# frozen_string_literal: true

class SavePatientRecordService
  include CouchdbSync
  # Defines expected required fields and their keys within the record hash.
  RequiredFields = Struct.new(:program_id, :provider_id, :location_id, :encounter_datetime)
  # Defines expected ID fields and their keys within the record hash.
  PatientIds = Struct.new(:national_id, :ichis_id, :birth_id)
  OperationResult = Struct.new(:success, :errors, keyword_init: true) do
    def success?
      success
    end

    def failed?
      !success
    end
  end

  ENCOUNTER_TYPE_MAPPING = {
    lab_orders: 'LAB ORDERS',
    lab_results: 'LAB RESULTS',
    medical_history: 'MEDICAL HISTORY',
    patient_registration: 'PATIENT REGISTRATION',
    treatment: 'TREATMENT',
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

        if operation_results.any? { |_k, result| result.failed? }
          failed_ops_list = operation_results.select { |_k, result| result.failed? }.keys.join(', ')
          Rails.logger.error("Overall record saving for patient #{patient_id} had failures in: #{failed_ops_list}")
          overall_sync_status = 'partial_failed'
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
    patient_record = build_and_save_patient_record(patient_id, record, operation_results, overall_sync_status)

    if couchdb_configured?
      patient_record["_id"] = patient_record["ID"]
      sync_to_couchdb(patient_record, "patients_records", "#{patient_record["ID"]}")
    end

    patient_record
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
      lab_data_manager: PatientRecordService::LabDataManager.new,
      vaccine_manager: PatientRecordService::VaccineManager.new,
      sms_manager: PatientRecordService::SmsManager.new,
      medication_order_saver: PatientRecordService::MedicationOrderSaver.new,
      dispensation_saver: PatientRecordService::DispensationSaver.new,
      observation_saver: PatientRecordService::ObservationSaver.new,
      void_encounters: PatientRecordService::VoidEncounters.new,
      void_drug_orders: PatientRecordService::VoidDrugOrders.new
    }
  end

  def execute_patient_operations(patient_id, record, managers)
    {
      update_person_info: run_operation(managers[:identity_manager], "Failed to update person information") do
        managers[:identity_manager].update_person_information(patient_id, record)
      end,
      manage_guardian: run_operation(managers[:guardian_manager], "Failed to manage guardian information") do
        managers[:guardian_manager].manage_guardian(patient_id, record)
      end,
      create_relationship: run_operation(managers[:guardian_manager], "Failed to create guardian relationship") do
        managers[:guardian_manager].create_relationship(record)
      end,
      enroll_program: run_operation(managers[:enrollment_manager], "Failed to enroll patient into selected program") do
        managers[:enrollment_manager].enroll_program(patient_id, record)
      end,
      save_lab_orders_data: run_operation(managers[:lab_data_manager], "Failed to save lab orders") do
        managers[:lab_data_manager].save_lab_orders_data(patient_id, record)
      end,
      save_lab_results_data: run_operation(managers[:lab_data_manager], "Failed to save lab results") do
        managers[:lab_data_manager].save_lab_results_data(patient_id, record)
      end,
      void_lab_order: run_operation(managers[:lab_data_manager], "Failed to void lab order") do
        managers[:lab_data_manager].void_lab_order(patient_id, record)
      end,
      save_vaccines: run_operation(managers[:vaccine_manager], "Failed to save vaccine administration") do
        managers[:vaccine_manager].save_vaccines(patient_id, record)
      end,
      send_sms: run_operation(managers[:sms_manager], "Failed to queue appointment SMS") do
        managers[:sms_manager].send_sms(patient_id, record)
      end,
      void_vaccine: run_operation(managers[:vaccine_manager], "Failed to void vaccine order") do
        managers[:vaccine_manager].void_vaccine(patient_id, record)
      end,
      save_medication_order: run_operation(managers[:medication_order_saver], "Failed to save medication order") do
        managers[:medication_order_saver].save_medication_order(patient_id, record)
      end,
      create_ncd_identifier: run_operation(managers[:identity_manager], "Failed to create NCD identifier") do
        managers[:identity_manager].create_ncd_identifier(patient_id, record)
      end,
      save_dispensation_data: run_operation(managers[:medication_order_saver], "Failed to save dispensation data") do
        managers[:medication_order_saver].save_dispensation_data(patient_id, record)
      end,
      save_all_observations: run_operation(managers[:observation_saver], "Failed to save observations") do
        managers[:observation_saver].save_all_observations(patient_id, record)
      end,
      void_encounters: run_operation(managers[:void_encounters], "Failed to void one or more encounters") do
        managers[:void_encounters].void_encounters(record)
      end,
      void_drug_orders: run_operation(managers[:void_drug_orders], "Failed to void one or more drug orders") do
        managers[:void_drug_orders].void_drug_orders(patient_id, record)
      end
    }
  end

  def run_operation(manager, fallback_error)
    manager.clear_errors! if manager.respond_to?(:clear_errors!)

    operation_outcome = yield
    manager_errors = manager.respond_to?(:errors) ? Array(manager.errors).compact : []

    return failure_result(manager_errors) if manager_errors.any?
    return success_result if operation_outcome == false || operation_outcome.nil?

    success_result
  rescue StandardError => e
    manager_errors = manager.respond_to?(:errors) ? Array(manager.errors).compact : []
    manager_errors << "#{fallback_error}: #{e.message}" if manager_errors.empty?
    failure_result(manager_errors)
  end

  def success_result
    OperationResult.new(success: true, errors: [])
  end

  def failure_result(errors)
    OperationResult.new(success: false, errors: Array(errors))
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
    patient_data[:visits] = BuildPatientRecordService.safe_get_visits(patient)
    patient_data[:activePrograms] = BuildPatientRecordService.fetch_active_programs(patient.patient_id)
    
    # Track encounter types that need rebuilding
    allowed_encounter_types = []
    
    # Update specific sections based on successful operations
    operation_results.each do |key, result|
      next unless result.success?

      case key
      when :update_person_info
        name = person&.names&.first
        address = person&.addresses&.first
        patient_data[:personInformation] = BuildPatientRecordService.build(person, name, address, patient)
        
      when :manage_guardian, :create_relationship
        patient_data[:guardianInformation] = BuildPatientRecordService.build_guardian_data(patient_id)
        patient_data[:relationships] = []
        
      when :enroll_program
        patient_data[:activePrograms] = BuildPatientRecordService.fetch_active_programs(patient_id)
        
      when :save_lab_orders_data, :save_lab_results_data, :void_lab_order
        patient_data[:labOrders] = BuildPatientRecordService.build_lab_orders_data(patient_id)
        allowed_encounter_types << get_encounter_id('LAB ORDERS') 
        allowed_encounter_types << get_encounter_id('LAB RESULTS') 
        
      when :save_vaccines, :void_vaccine
        patient_data[:vaccineAdministration] = BuildPatientRecordService.build_vaccine_administration_data(patient_id)
        patient_data[:vaccineSchedule] = BuildPatientRecordService.safe_get_vaccine_schedule(person)
        
      when :save_medication_order, :save_dispensation_data
        patient_data[:MedicationOrder] = BuildPatientRecordService.build_medication_data(patient_id)
        allowed_encounter_types << get_encounter_id('TREATMENT') 
        
      when :create_ncd_identifier
        patient_data[:NcdID] = BuildPatientRecordService.patient_identifier(patient, 31)

      when :void_drug_orders
        patient_data[:voidedDrugOders] = BuildPatientRecordService.build_voided_drug_orders_data(patient)

      when :void_encounters
        # Extract encounter types from voided encounters to rebuild them
        voided_encounter_ids = patient_data.dig(:void_encounters)&.map { |ve| ve[:id] }&.compact || []
        
        if voided_encounter_ids.any?
          # Get encounter types for the voided encounters (use unscoped to bypass default scope)
          voided_encounter_types = Encounter.unscoped
                                            .where(encounter_id: voided_encounter_ids)
                                            .pluck(:encounter_type)
                                            .uniq
          allowed_encounter_types.concat(voided_encounter_types)
        end
    
        # Clear void_encounters after processing
        patient_data[:void_encounters] = []
       
        
      when :save_all_observations
        # Extract encounter types from observations that were marked as unsaved
        unsaved_encounter_types = patient_data[:observations]
                                    &.select { |e| e[:status] == "unsaved" }
                                    &.map { |e| e[:encounter_type] }
                                    &.uniq || []
        allowed_encounter_types.concat(unsaved_encounter_types)
      end
    end
    
    patient_data[:MedicationOrder] = BuildPatientRecordService.build_medication_data(patient_id)
    allowed_encounter_types << get_encounter_id('TREATMENT') 
    # Rebuild observations for collected encounter types
    rebuild_all_observations(patient_id, patient_data, allowed_encounter_types)
    
    patient_data[:operation_errors] = operation_results
      .select { |_key, result| result.failed? && result.errors.any? }
      .transform_values(&:errors)
      .as_json

    # Return the patient data as JSON
    patient_data.as_json
  end

  def get_encounter_id(encounter_type)
    EncounterType.find_by_name(encounter_type).encounter_type_id
  end
  
  def rebuild_all_observations(patient_id, patient_data, allowed_encounter_types)
    # Remove duplicates and filter out nil/empty values
    allowed_encounter_types = allowed_encounter_types.compact.uniq
    
    # Exit early if no encounter types to rebuild
    return if allowed_encounter_types.empty?
    
    # Create a map of original observations by encounter type
    original_observations_map = (patient_data[:observations] || [])
                                  .each_with_object({}) do |obs, hash|
                                    hash[obs[:encounter_type]] = obs
                                  end

    # Build new observations for the allowed encounter types
    new_observations = BuildPatientRecordService.build_all_observations(patient_id, allowed_encounter_types)
    
    # Merge new observations into the original map (new observations override)
    updated_observations_hash = original_observations_map.merge(
      new_observations.index_by { |obs| obs[:encounter_type] }
    )
    
    # Update patient_data with merged observations
    patient_data[:observations] = updated_observations_hash.values.as_json
  end
end
