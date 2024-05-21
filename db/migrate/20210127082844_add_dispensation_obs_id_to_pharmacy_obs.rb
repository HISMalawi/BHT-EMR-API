# frozen_string_literal: true

class AddDispensationObsIdToPharmacyObs < ActiveRecord::Migration[5.2]
  def up
    add_column :pharmacy_obs, :dispensation_obs_id, :integer, null: true unless column_exists?(:pharmacy_obs,
                                                                                               :dispensation_obs_id)
    add_foreign_key :pharmacy_obs, :obs, column: :dispensation_obs_id, primary_key: :obs_id unless foreign_key_exists?(
      :pharmacy_obs, :obs
    )
  end

  def down
    remove_column :pharmacy_obs, :dispensation_obs_id
  end
end
