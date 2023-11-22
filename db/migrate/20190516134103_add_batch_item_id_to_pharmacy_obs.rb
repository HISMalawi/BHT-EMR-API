# frozen_string_literal: true

class AddBatchItemIdToPharmacyObs < ActiveRecord::Migration[5.2]
  def up
    add_column :pharmacy_obs, :batch_item_id, :integer unless column_exists?(:pharmacy_obs, :batch_item_id)
  end

  def down
    remove_column :pharmacy_obs, :batch_item_id
  end
end
