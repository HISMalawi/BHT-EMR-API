class CreateProviders < ActiveRecord::Migration[5.2]
  def change
    create_table :providers do |t|
      t.integer :person_id, null: false
      t.string :name, null: false
      t.string :identifier, null: false
      t.integer :creator, null: false
      t.datetime :date_created, null: false
      t.integer :changed_by, null: false
      t.datetime :date_changed, null: false
      t.boolean :retired, null: false, default: false
      t.integer :retired_by, null: true
      t.datetime :date_retired, null: true
      t.string :retire_reason, null: true
      t.string :uuid, limit: 38, null: false
      t.bigint :provider_role_id, null: false
    end

    add_foreign_key :providers, :person, column: :person_id, primary_key: :person_id
    add_foreign_key :providers, :users, column: :creator, primary_key: :user_id
    add_foreign_key :providers, :users, column: :changed_by, primary_key: :user_id
    add_foreign_key :providers, :users, column: :retired_by, primary_key: :user_id
    add_foreign_key :providers, :providermanagement_provider_roles, column: :provider_role_id, primary_key: :id
    add_index :providers, :uuid, unique: true
  end
end
