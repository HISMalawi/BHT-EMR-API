class AddPackSizeToPharmacyBatchItem < ActiveRecord::Migration[5.2]
  def change
    add_column :pharmacy_batch_items, :pack_size, :integer, null: true
  end
end
