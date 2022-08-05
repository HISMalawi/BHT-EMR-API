class CreateEncounterRoles < ActiveRecord::Migration[5.2]
  def change
    create_table :encounter_role, id: false do |t|
      t.primary_key :encounter_role_id
      t.string :name, null: false, limit: 255
      t.string :description, null: false, limit: 1024
      t.integer :creator, null: false
      t.datetime :date_created, null: false
      t.integer :changed_by, null: true
      t.datetime :date_changed, null: true
      t.boolean :retired, default: false, null: false
      t.integer :retired_by, null: true
      t.datetime :date_retired, null: true
      t.string :retire_reason, null: true, limit: 255
      t.string :uuid, limit: 38, null: false, unique: true
    end
    add_foreign_key :encounter_role, :users, column: :creator, primary_key: :user_id
    add_foreign_key :encounter_role, :users, column: :changed_by, primary_key: :user_id
    add_foreign_key :encounter_role, :users, column: :retired_by, primary_key: :user_id
  end
end
