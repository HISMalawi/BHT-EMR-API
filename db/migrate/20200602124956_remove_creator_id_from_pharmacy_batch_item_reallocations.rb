class RemoveCreatorIdFromPharmacyBatchItemReallocations < ActiveRecord::Migration[5.2]
  def change
    remove_column :pharmacy_batch_item_reallocations, :creator_id, :integer, null: false, default: 1
  end
end
