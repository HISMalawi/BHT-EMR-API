# app/jobs/sync/stock_sync_job.rb
module Sync
  class StockSyncJob < BaseSyncJob
    # Sync all pharmacy batch items (stock) to CouchDB
    def perform(batch_size = 100)
      sync_records_to_couchdb(PharmacyBatchItem, 'stock', batch_size) do |model_class|
        model_class
          .joins('INNER JOIN drug ON drug.drug_id = pharmacy_batch_items.drug_id')
          .joins('INNER JOIN pharmacy_batches ON pharmacy_batches.id = pharmacy_batch_items.pharmacy_batch_id')
          .where(voided: false)
          .where("DATE(pharmacy_batch_items.expiry_date) >= ?", Date.today)
          .where('current_quantity > 0')
          .where('expiry_date > ?', "#{ Date.today}")
      end
    end

    private

    def prepare_document(stock_item)
      # Fetch location_id from pharmacy_batches table
      pharmacy_batch = ::PharmacyBatch.where(id: stock_item.pharmacy_batch_id)
                                      .pluck(:location_id, :batch_number)
                                      .first
      
      location_id = pharmacy_batch&.first
      batch_number = pharmacy_batch&.last

      # Calculate doses_wasted
      doses_wasted = ::PharmacyBatchItemReallocation
        .where(batch_item_id: stock_item.id)
        .sum(:quantity).to_f || 0.0

      # Calculate dispensed_quantity
      base_dispensed = (stock_item.delivered_quantity.to_f || 0.0) - 
                       ((stock_item.current_quantity.to_f || 0.0) + doses_wasted)
      
      # Query pharmacy_obs table directly using raw SQL
      adjustments_query = <<~SQL
        SELECT COALESCE(SUM(quantity), 0) as total
        FROM pharmacy_obs
        WHERE batch_item_id = #{ActiveRecord::Base.connection.quote(stock_item.id)}
        AND transaction_reason IN (
          #{ActiveRecord::Base.connection.quote('Positive Adjustment')}, 
          #{ActiveRecord::Base.connection.quote('Negative Adjustment')},
          #{ActiveRecord::Base.connection.quote('Positive Mathematical Error')}, 
          #{ActiveRecord::Base.connection.quote('Negative Mathematical Error')}
        )
      SQL
      
      result = ActiveRecord::Base.connection.select_one(adjustments_query)
      adjustments = result['total'].to_f rescue 0.0

      dispensed_quantity = [base_dispensed, 0].max + adjustments

      {
        "dispensed_quantity" => dispensed_quantity,
        "doses_wasted" => doses_wasted,
        "batch_number" => batch_number,
        "drug_legacy_name" => stock_item.drug&.name,
        "type" => "stock",
        "stock_id" => stock_item.id,
        "pharmacy_batch_id" => stock_item.pharmacy_batch_id,
        "location_id" => location_id,
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