class AddDateToPharmacyBatchItemReallocation < ActiveRecord::Migration[5.2]
  def change
    add_column :pharmacy_batch_item_reallocations, :date, :date, options: -> { 'DEFAULT NOW()' }
  end
end
