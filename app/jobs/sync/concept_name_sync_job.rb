# app/jobs/sync/concept_name_sync_job.rb
module Sync
  class ConceptNameSyncJob < BaseSyncJob
    
    # Sync all concept names to CouchDB
    def perform(batch_size = 50) # Smaller default batch size due to large dataset
      sync_records_to_couchdb(ConceptName, 'concept_names', batch_size) do |model_class|
        model_class.where(voided: 0)
      end
    end
    
    private
    
    def prepare_document(concept_name)
      {
        "type" => "concept_name",
        "concept_name_id" => concept_name.concept_name_id,
        "concept_id" => concept_name.concept_id,
        "name" => concept_name.name,
        "locale" => concept_name.locale,
        "concept_name_type" => concept_name.concept_name_type,
        "locale_preferred" => concept_name.locale_preferred,
        "creator" => concept_name.creator,
        "voided" => concept_name.voided,
        "voided_by" => concept_name.voided_by,
        "void_reason" => concept_name.void_reason,
        "uuid" => concept_name.uuid,
        "date_created" => concept_name.date_created&.iso8601,
        "date_voided" => concept_name.date_voided&.iso8601,
        "synced_at" => Time.current.iso8601
      }
    end
    
    def generate_document_id(concept_name)
      "concept_name_#{concept_name.concept_name_id}"
    end
  end
end

# Usage examples:
# Sync::ConceptNameSyncJob.perform_async(25)  # Even smaller batches for large dataset
# Sync::ConceptNameSyncJob.perform_async      # Default batch size of 50