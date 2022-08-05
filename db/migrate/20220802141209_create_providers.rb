class CreateProviders < ActiveRecord::Migration[5.2]
  def change
    create_table :provider, id: false do |t|
      t.primary_key :provider_id
      t.integer :person_id, null: false
      t.string :name, null: false, limit: 255
      t.string :identifier, null: false
      t.integer :creator, null: false
      t.datetime :date_created, null: false
      t.integer :changed_by, null: false
      t.datetime :date_changed, null: false
      t.boolean :retired, null: false, default: false
      t.integer :retired_by, null: true
      t.datetime :date_retired, null: true
      t.string :retire_reason, null: true, limit: 255
      t.string :uuid, limit: 38, null: false, unique: true
      t.bigint :provider_role_id, null: false
    end

    add_foreign_key :provider, :person, column: :person_id, primary_key: :person_id
    add_foreign_key :provider, :users, column: :creator, primary_key: :user_id
    add_foreign_key :provider, :users, column: :changed_by, primary_key: :user_id
    add_foreign_key :provider, :users, column: :retired_by, primary_key: :user_id
    add_foreign_key :provider, :providermanagement_provider_role, column: :provider_role_id, primary_key: :provider_role_id
  end
end
