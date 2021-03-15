class CreatePharmacyBatchItems < ActiveRecord::Migration[5.2]
  def change
    create_table :pharmacy_batch_items do |t|
      t.integer :pharmacy_batch_id
      t.integer :drug_id
      t.float :delivered_quantity
      t.float :current_quantity
      t.date :delivery_date
      t.date :expiry_date
      t.integer :creator, null: false
      t.datetime :date_created, null: false, default: -> { 'NOW()' }
      t.datetime :date_changed, default: -> { 'NOW()' }
      t.boolean :voided
      t.integer :voided_by
      t.string :void_reason
      t.datetime :date_voided
    end
  end
end
