class CreateMohRegimenCombinationDrugs < ActiveRecord::Migration[5.2]
  def change
    return if table_exists?(:moh_regimen_combination_drug)

    create_table :moh_regimen_combination_drug, id: false do |t|
      t.integer :regimen_combination_drug_id, primary_key: true
      t.integer :regimen_combination_id, null: false
      t.integer :drug_id, null: false

      t.timestamps
    end
  end
end
