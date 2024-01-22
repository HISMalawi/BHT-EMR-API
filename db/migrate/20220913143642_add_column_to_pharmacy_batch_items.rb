# frozen_string_literal: true

class AddColumnToPharmacyBatchItems < ActiveRecord::Migration[5.2]
  def change
    add_column :pharmacy_batch_items, :product_code, :string
  end
end
