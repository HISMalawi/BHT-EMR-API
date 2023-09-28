# frozen_string_literal: true

# Migration to add a column to the pharmacy_obs table
class AddPharmacyObsGroupIdToPharmacyObsTable < ActiveRecord::Migration[5.2]
  def change
    # the obs_group_id column references the pharmacy_module_id column
    # can be null
    add_column :pharmacy_obs, :obs_group_id, :integer, null: true

    # add a foreign key constraint
    add_foreign_key :pharmacy_obs, :pharmacy_obs, column: :obs_group_id, primary_key: :pharmacy_module_id
  end
end
