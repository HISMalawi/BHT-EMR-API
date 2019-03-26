class CreateAlternativeDrugNames < ActiveRecord::Migration[5.2]
  def change
    create_table :alternative_drug_names do |t|
      t.string :name, null: false
      t.string :short_name
      t.integer :drug_inventory_id, null: false

      t.timestamps
    rescue StandardError => e
      Rails.logger.warn("CreateAlternativeDrugNames migration failed: #{e}")
    end
  end
end
