class CreatePharmacyBatchVvms < ActiveRecord::Migration[5.2]
  def change
    create_table :pharmacy_batch_vvms do |t|
      t.string :vvm
      t.integer :batch_item_id
      t.boolean :voided
      t.integer :voided_by
      t.string :void_reason
      t.datetime :date_voided
      t.timestamps
    end
  end
end