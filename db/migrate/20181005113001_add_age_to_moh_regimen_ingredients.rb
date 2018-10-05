class AddAgeToMohRegimenIngredients < ActiveRecord::Migration[5.2]
  def change
    add_column :moh_regimen_ingredient, :min_age, :integer
    add_column :moh_regimen_ingredient, :max_age, :integer
  end
end
