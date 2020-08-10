class CreateMohRegimenCombinations < ActiveRecord::Migration[5.2]
  def change
    create_table :moh_regimen_combination, id: false do |t|
      t.integer :regimen_combination_id, primary_key: true
      t.integer :regimen_name_id, null: false

      t.timestamps
    end
  end
end
