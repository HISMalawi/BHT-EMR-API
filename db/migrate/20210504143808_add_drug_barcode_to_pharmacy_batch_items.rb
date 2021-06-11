class AddDrugBarcodeToPharmacyBatchItems < ActiveRecord::Migration[5.2]
  def change
    add_column :pharmacy_batch_items, :barcode, :string unless column_exists?(:pharmacy_batch_items, :barcode)
  end
end
