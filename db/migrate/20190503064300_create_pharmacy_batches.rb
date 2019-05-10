class CreatePharmacyBatches < ActiveRecord::Migration[5.2]
  def change
    create_table :pharmacy_batches do |t|
      t.string :batch_number
      t.integer :creator, null: false
      t.datetime :date_created, null: false, default: -> { 'NOW()' }
      t.datetime :date_changed, options: -> { 'NOW()' }
      t.boolean :voided
      t.integer :voided_by
      t.string :void_reason
      t.datetime :date_voided
    end
  end
end
