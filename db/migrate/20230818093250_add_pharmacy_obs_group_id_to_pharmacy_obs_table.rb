# frozen_string_literal: true

# Migration to add a column to the pharmacy_obs table
class AddPharmacyObsGroupIdToPharmacyObsTable < ActiveRecord::Migration[5.2]
  def up
    # the obs_group_id column references the pharmacy_module_id column
    # can be null
    unless column_exists?(:pharmacy_obs, :obs_group_id)
      add_column :pharmacy_obs, :obs_group_id, :integer, null: true
      add_foreign_key :pharmacy_obs, :pharmacy_obs, column: :obs_group_id, primary_key: :pharmacy_module_id
    end
  end

  def down
    remove_foreign_key :pharmacy_obs, column: :obs_group_id
    remove_column :pharmacy_obs, :obs_group_id
  end
end
