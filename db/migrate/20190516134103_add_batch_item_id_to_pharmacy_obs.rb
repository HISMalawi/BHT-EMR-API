# frozen_string_literal: true

class AddBatchItemIdToPharmacyObs < ActiveRecord::Migration[5.2]
  def change
    add_column :pharmacy_obs, :batch_item_id, :integer
  end
end
