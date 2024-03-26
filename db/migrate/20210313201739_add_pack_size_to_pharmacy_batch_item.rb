# frozen_string_literal: true

class AddPackSizeToPharmacyBatchItem < ActiveRecord::Migration[5.2]
  def change
    return if column_exists?(:pharmacy_batch_items, :pack_size)

    add_column :pharmacy_batch_items, :pack_size, :integer, null: true
  end
end
