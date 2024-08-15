class AddDetailsToPharmacyBatchItems < ActiveRecord::Migration[5.2]
  def change
    add_column :pharmacy_batch_items, :unit_doses, :float
    add_column :pharmacy_batch_items, :manufacture, :string
    add_column :pharmacy_batch_items, :dosage_form, :string
  end
end
