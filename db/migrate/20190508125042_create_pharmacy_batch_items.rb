class CreatePharmacyBatchItems < ActiveRecord::Migration[5.2]
  def change
    create_table :pharmacy_batch_items do |t|
      t.integer :pharmacy_batch_id
      t.integer :drug_id
      t.float :delivered_quantity
      t.float :current_quantity
      t.date :delivery_date
      t.date :expiry_date
      t.boolean :voided
      t.integer :voided_by
      t.string :void_reason
      t.date :date_voided

      t.timestamps
    end
  end
end
