# app/jobs/sync/facility_sync_job.rb
module Sync
  class FacilitySyncJob < BaseSyncJob
    
    # Sync all facilities to CouchDB
    def perform(batch_size = 100)
      sync_records_to_couchdb(Location, 'facilities', batch_size) do |model_class|
        model_class.where(retired: false)
                  .where.not(city_village: [nil, ""])
      end
    end
    
    private
    
    def prepare_document(facility)
      {
        "type" => "facility",
        "dde_activated" => false,
        "location_id" => facility.location_id,
        "name" => facility.name,
        "district" => facility.city_village,
        "latitude" => facility.latitude,
        "longitude" => facility.longitude,
        "date_created" => facility.date_created&.iso8601,
        "synced_at" => Time.current.iso8601
      }
    end
    
    def generate_document_id(facility)
      "facility_#{facility.location_id}"
    end
  end
end

# Usage examples:
# Sync::FacilitySyncJob.perform_async(50)  # Smaller batches
# Sync::FacilitySyncJob.perform_async      # Default batch size of 100