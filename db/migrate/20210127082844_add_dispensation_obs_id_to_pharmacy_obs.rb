# frozen_string_literal: true

class AddDispensationObsIdToPharmacyObs < ActiveRecord::Migration[5.2]
  def change
    add_column :pharmacy_obs, :dispensation_obs_id, :integer, null: true
    add_foreign_key :pharmacy_obs, :obs, column: :dispensation_obs_id, primary_key: :obs_id
  end
end
