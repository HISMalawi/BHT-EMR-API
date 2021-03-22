class AddChangedByToPharmacyBatchItem < ActiveRecord::Migration[5.2]
  def change
    add_column :pharmacy_batch_items, :changed_by, :integer, default: nil
    add_column :pharmacy_batches, :changed_by, :integer, default: nil
  end
end
