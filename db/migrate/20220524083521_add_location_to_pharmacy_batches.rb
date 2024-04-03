# frozen_string_literal: true

class AddLocationToPharmacyBatches < ActiveRecord::Migration[5.2]
  def change
    add_column :pharmacy_batches, :location_id, :integer, null: true
    add_foreign_key :pharmacy_batches, :location, column: :location_id, primary_key: :location_id
  end
end
