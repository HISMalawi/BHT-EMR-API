class IndexPharmacyBatchItemReallocationType < ActiveRecord::Migration[5.2]
  def change
    add_index :pharmacy_batch_item_reallocations, :reallocation_type
  end
end
