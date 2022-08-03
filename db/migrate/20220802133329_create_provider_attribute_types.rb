class CreateProviderAttributeTypes < ActiveRecord::Migration[5.2]
  def change
    create_table :provider_attribute_types do |t|
      t.string :name, null: false
      t.string :description, null: true
      t.string :datatype, null: true
      t.text :datatype_config, null: true
      t.string :preferred_handler, null: true
      t.string :handler_config, null: true
      t.integer :min_occurs, default: 0, null: false
      t.integer :max_occurs, null: true
      t.integer :creator, null: false
      t.datetime :date_created, null: false
      t.integer :changed_by, null: true
      t.datetime :date_changed, null: false
      t.boolean :retired, null: false, default: false
      t.integer :retired_by, null: true
      t.datetime :date_retired, default: nil
      t.string :retire_reason, null: true
      t.string :uuid, limit: 38, null: false
    end
    add_foreign_key :provider_attribute_types, :users, column: :creator, primary_key: :user_id
    add_foreign_key :provider_attribute_types, :users, column: :changed_by, primary_key: :user_id
    add_foreign_key :provider_attribute_types, :users, column: :retired_by, primary_key: :user_id
    add_index :provider_attribute_types, :uuid, unique: true
  end
end
