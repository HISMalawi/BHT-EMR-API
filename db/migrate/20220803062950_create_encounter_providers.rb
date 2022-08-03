class CreateEncounterProviders < ActiveRecord::Migration[5.2]
  def change
    create_table :encounter_providers do |t|
      t.integer :encounter_id, null: false
      t.bigint :provider_id, null: false
      t.bigint :encounter_role_id, null: false
      t.integer :creator, null: false
      t.datetime :date_created, null: false
      t.integer :changed_by, null: false
      t.datetime :date_changed, null: false
      t.boolean :voided, null: false, default: false
      t.datetime :date_voided, null: true
      t.integer :voided_by, null: true
      t.string :void_reason, null: true
      t.string :uuid, null: false, unique: true, index: true, limit: 32
    end
    add_foreign_key :encounter_providers, :encounter, column: :encounter_id, primary_key: :encounter_id
    add_foreign_key :encounter_providers, :providers, column: :provider_id, primary_key: :id
    add_foreign_key :encounter_providers, :encounter_roles, column: :encounter_role_id, primary_key: :id
    add_foreign_key :encounter_providers, :users, column: :creator, primary_key: :user_id
    add_foreign_key :encounter_providers, :users, column: :changed_by, primary_key: :user_id
    add_foreign_key :encounter_providers, :users, column: :voided_by, primary_key: :user_id
  end
end
