class AddCreatorIdToPharmacyBatchItem < ActiveRecord::Migration[5.2]
  def change
    add_column :pharmacy_batch_item_reallocations, :creator_id, :integer, null: false
  end
end
