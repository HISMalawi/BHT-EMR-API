# frozen_string_literal: true

class AddReallocationTypeToPharmacyBatchItemReallocation < ActiveRecord::Migration[5.2]
  def change
    add_column :pharmacy_batch_item_reallocations, :reallocation_type, :string
  end
end
