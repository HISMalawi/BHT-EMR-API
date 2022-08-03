class CreateEncounterRoles < ActiveRecord::Migration[5.2]
  def change
    create_table :encounter_roles do |t|
      t.string :name, null: false
      t.string :description, null: false
      t.integer :creator, null: false
      t.datetime :date_created, null: false
      t.integer :changed_by, null: true
      t.datetime :date_changed, null: true
      t.boolean :retired, default: false, null: false
      t.integer :retired_by, null: true
      t.datetime :date_retired, null: true
      t.string :retire_reason, null: true
      t.string :uuid, limit: 38, null: false
    end
    add_foreign_key :encounter_roles, :users, column: :creator, primary_key: :user_id
    add_foreign_key :encounter_roles, :users, column: :changed_by, primary_key: :user_id
    add_foreign_key :encounter_roles, :users, column: :retired_by, primary_key: :user_id
    add_index :encounter_roles, :uuid, unique: true
  end
end
