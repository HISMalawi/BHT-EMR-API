module Sync
  class BatchPatientSyncJob
    include Sidekiq::Job
    sidekiq_options queue: :batch_sync, retry: 3

    def perform(location_id = nil, since_date = nil)
      if location_id.present?
        Rails.logger.info("Starting batch patient sync for location #{location_id}")
      else
        Rails.logger.info("Starting batch patient sync for ALL locations")
      end
      since_date = CouchdbPatientService.get_latest_encounter_date_changed
      # Get unique patient IDs that need syncing
      patient_ids = get_patient_ids_to_sync(location_id, since_date)
      
      total_count = patient_ids.count
      Rails.logger.info("Found #{total_count} unique patients to sync")

      # Process in batches to avoid memory issues
      counter = 0
      patient_ids.each_slice(100) do |batch_ids|
        batch_ids.each do |patient_id|
          # Queue individual sync jobs
          PatientRecordSyncJob.perform_async(
            patient_id,
            { 'location_id' => location_id }
          )
          counter += 1
        end
        
        # Log progress periodically
        Rails.logger.info("Queued #{counter}/#{total_count} patient sync jobs") if counter % 1000 == 0
      end

      location_msg = location_id.present? ? "for location #{location_id}" : "for ALL locations"
      Rails.logger.info("Completed queuing #{counter} batch patient sync jobs #{location_msg}")
    end

    private

    def get_patient_ids_to_sync(location_id, since_date)
      # Build base query for patient IDs
      query = Patient.joins(:encounters)
                    .select('patients.patient_id')
                    .distinct

      # Add location filter if provided
      if location_id.present?
        query = query.where(encounters: { location_id: location_id })
      end

      # Add date filter if provided
      if since_date.present?
        parsed_date = Time.zone.parse(since_date.to_s)
        query = query.where('encounter.date_created >= ?', parsed_date)
      end

      # Return array of patient IDs to avoid issues with complex joined queries
      query.pluck(:patient_id).uniq
    end
  end
end