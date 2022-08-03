class CreateProvidermanagementProviderRoles < ActiveRecord::Migration[5.2]
  def change
    create_table :providermanagement_provider_roles do |t|
      t.string :name, null: false
      t.string :description, null: true
      t.integer :creator
      t.datetime :date_created, null: false
      t.integer :changed_by, null: false
      t.datetime :date_changed, null: false
      t.boolean :retired, null: false, default: false
      t.integer :retired_by, null: true
      t.datetime :date_retired, null: true
      t.string :retire_reason, null: true
      t.string :uuid, limit: 38, null: false
    end
    add_foreign_key :providermanagement_provider_roles, :users, column: :creator, primary_key: :user_id
    add_foreign_key :providermanagement_provider_roles, :users, column: :changed_by, primary_key: :user_id
    add_foreign_key :providermanagement_provider_roles, :users, column: :retired_by, primary_key: :user_id
    add_index :providermanagement_provider_roles, :uuid, unique: true
  end
end
