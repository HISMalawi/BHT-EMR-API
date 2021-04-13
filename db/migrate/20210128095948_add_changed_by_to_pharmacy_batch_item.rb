class AddChangedByToPharmacyBatchItem < ActiveRecord::Migration[5.2]
  def change
    unless column_exists?(:pharmacy_batch_items, :changed_by)
      add_column :pharmacy_batch_items, :changed_by, :integer, default: nil
    end

    unless column_exists?(:pharmacy_batches, :changed_by)
      add_column :pharmacy_batches, :changed_by, :integer, default: nil
    end
  end
end
