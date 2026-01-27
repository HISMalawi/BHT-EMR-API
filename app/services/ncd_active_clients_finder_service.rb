class NcdActiveClientsFinderService
  def find_active_clients()
    Rails.logger.info("Finding active clients")
    service = FacilityService.new
    result = service.list_facility_codes()
    Rails.logger.info("Found #{result[:total]} facilities")
    
    result[:facility_codes].each do |facility|
      Rails.logger.info("Processing facility: #{facility}")
      begin
        ncd_active_patients(facility[:code])
      rescue StandardError => e
        Rails.logger.error("Error processing facility #{facility[:code]}: #{e.message}")
        # Continue processing other facilities instead of failing the entire job
      end
    end
  end

  def ncd_active_patients(location_id)
    Rails.logger.info("Processing NCD patients for location: #{location_id}")
    
    @current_date = Date.current
    @location_id = location_id

    base_patients = Patient.joins(encounters: [:program, :type])
                          .where(program: { program_id: 32 })
                          .where(encounters: { location_id: @location_id })
                          .where(encounter_type: { name: ['PATIENT REGISTRATION', 'REGISTRATION'] })
                          .distinct
    
    patient_count = base_patients.count
    Rails.logger.info("Found #{patient_count} patients for location #{location_id}")
    
    if patient_count > 0
      MongoSyncService.new.sync_patients_to_mongo(base_patients, @location_id)
      Rails.logger.info("Successfully synced #{patient_count} patients to MongoDB for location #{location_id}")
    else
      Rails.logger.info("No patients found for location #{location_id}")
    end
  end
end