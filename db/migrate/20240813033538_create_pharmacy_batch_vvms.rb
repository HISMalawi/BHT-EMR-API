class CreatePharmacyBatchVvms < ActiveRecord::Migration[5.2]
  def change
    create_table :pharmacy_batch_vvms do |t|
      t.string :vvm
      t.integer :pharmacy_batch_id
      t.timestamps
    end
  end
end

