# frozen_string_literal: true

# This migration adds min_age and max_age columns to moh_regimen_ingredient table
class AddAgeToMohRegimenIngredients < ActiveRecord::Migration[5.2]
  def up
    # first check if the columns exist and skip if they already exists
    add_column :moh_regimen_ingredient, :min_age, :integer unless column_exists?(:moh_regimen_ingredient, :min_age)
    return if column_exists?(:moh_regimen_ingredient, :max_age)

    add_column :moh_regimen_ingredient, :max_age, :integer
  end

  def down
    remove_column :moh_regimen_ingredient, :min_age
    remove_column :moh_regimen_ingredient, :max_age
  end
end
