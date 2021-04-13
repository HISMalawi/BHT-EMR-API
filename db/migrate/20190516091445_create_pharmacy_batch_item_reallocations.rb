class CreatePharmacyBatchItemReallocations < ActiveRecord::Migration[5.2]
  def change
    create_table :pharmacy_batch_item_reallocations do |t|
      t.string :reallocation_code
      t.integer :batch_item_id
      t.float :quantity
      t.integer :location_id

      t.timestamps
    end
  end
end
