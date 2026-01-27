# app/jobs/sync/stock_sync_job.rb
module Sync
  class StockSyncJob < BaseSyncJob
    # Sync all pharmacy batch items (stock) to CouchDB
    def perform(batch_size = 100)
      sync_records_to_couchdb(PharmacyBatchItem, 'stock', batch_size) do |model_class|
        model_class.where(voided: false)
      end
    end

    private

    def prepare_document(stock_item)
      {
        "type" => "stock",
        "stock_id" => stock_item.id,
        "pharmacy_batch_id" => stock_item.pharmacy_batch_id,
        "drug_id" => stock_item.drug_id,
        "delivered_quantity" => stock_item.delivered_quantity,
        "current_quantity" => stock_item.current_quantity,
        "delivery_date" => stock_item.delivery_date&.iso8601,
        "expiry_date" => stock_item.expiry_date&.iso8601,
        "creator" => stock_item.creator,
        "date_created" => stock_item.date_created&.iso8601,
        "date_changed" => stock_item.date_changed&.iso8601,
        "voided" => stock_item.voided,
        "voided_by" => stock_item.voided_by,
        "void_reason" => stock_item.void_reason,
        "date_voided" => stock_item.date_voided&.iso8601,
        "changed_by" => stock_item.changed_by,
        "pack_size" => stock_item.pack_size,
        "barcode" => stock_item.barcode,
        "product_code" => stock_item.product_code,
        "unit_doses" => stock_item.unit_doses,
        "manufacture" => stock_item.manufacture,
        "dosage_form" => stock_item.dosage_form,
        "synced_at" => Time.current.iso8601
      }
    end

    def generate_document_id(stock_item)
      "stock_#{stock_item.id}"
    end
  end
end

# Usage examples:
# Sync::StockSyncJob.perform_async(50)  # Smaller batches
# Sync::StockSyncJob.perform_async      # Default batch size of 100