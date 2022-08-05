class CreateProviderAttributeTypes < ActiveRecord::Migration[5.2]
  def change
    create_table :provider_attribute_type, id: false do |t|
      t.primary_key :provider_attribute_type_id
      t.string :name, null: false, limit: 255
      t.string :description, null: true, limit: 1024
      t.string :datatype, null: true, limit: 255
      t.text :datatype_config, null: true
      t.string :preferred_handler, null: true, limit: 255
      t.text :handler_config, null: true
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
      t.string :uuid, limit: 38, null: false, unique: true
    end
    add_foreign_key :provider_attribute_type, :users, column: :creator, primary_key: :user_id
    add_foreign_key :provider_attribute_type, :users, column: :changed_by, primary_key: :user_id
    add_foreign_key :provider_attribute_type, :users, column: :retired_by, primary_key: :user_id
  end
end
