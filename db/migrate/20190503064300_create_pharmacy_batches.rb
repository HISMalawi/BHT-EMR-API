class CreatePharmacyBatches < ActiveRecord::Migration[5.2]
  def change
    create_table :pharmacy_batches do |t|
      t.string :batch_number
      t.boolean :voided
      t.integer :voided_by
      t.string :void_reason
      t.date :date_voided

      t.timestamps
    end
  end
end
