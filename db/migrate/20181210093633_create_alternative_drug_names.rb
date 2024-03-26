# frozen_string_literal: true

class CreateAlternativeDrugNames < ActiveRecord::Migration[5.2]
  def up
    return if table_exists?(:alternative_drug_names)

    create_table :alternative_drug_names do |t|
      t.string :name, null: false
      t.string :short_name
      t.integer :drug_inventory_id, null: false

      t.timestamps
    rescue StandardError => e
      Rails.logger.warn("CreateAlternativeDrugNames migration failed: #{e}")
    end
  end

  def down
    drop_table :alternative_drug_names if table_exists?(:alternative_drug_names)
  end
end
