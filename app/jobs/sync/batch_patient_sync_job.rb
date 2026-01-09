# app/jobs/sync/batch_patient_sync_job.rb
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
      
      since_date ||= CouchdbPatientService.get_latest_encounter_date_changed
      
      # Get unique patient IDs that need syncing
      patient_ids = get_patient_ids_to_sync(location_id, since_date)
      
      total_count = patient_ids.count
      Rails.logger.info("Found #{total_count} unique patients to sync")

      return if total_count.zero?

      # Process in batches and bulk enqueue jobs
      counter = 0
      patient_ids.each_slice(100) do |batch_ids|
        # Bulk enqueue jobs for this batch (much faster than individual perform_async calls)
        Sidekiq::Client.push_bulk(
          'class' => PatientRecordSyncJob,
          'queue' => 'patient_sync',
          'args' => batch_ids.map { |id| [id, { 'location_id' => location_id }] }
        )
        
        counter += batch_ids.size
        
        # Log progress periodically
        Rails.logger.info("Queued #{counter}/#{total_count} patient sync jobs") if counter % 1000 == 0
      end

      location_msg = location_id.present? ? "for location #{location_id}" : "for ALL locations"
      Rails.logger.info("Completed queuing #{counter} batch patient sync jobs #{location_msg}")
    end

    private

    def get_patient_ids_to_sync(location_id, since_date)
      
      query = Encounter.unscoped.select(:patient_id).distinct
      
      # Add location filter if provided
      query = query.where(location_id: location_id) if location_id.present?
      
      # Add date filter if provided
      if since_date.present?
        parsed_date = Time.zone.parse(since_date.to_s)
        query = query.where('encounter.date_created >= ? OR encounter.date_voided >= ?', parsed_date, parsed_date)
      end
      
      query.pluck(:patient_id)
    end
  end
end