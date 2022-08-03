class CreateLocationAttributeTypes < ActiveRecord::Migration[5.2]
  def change
    create_table :location_attribute_types do |t|
      t.string :name, null: false
      t.string :description, null: true
      t.string :datatype, null: true
      t.text :datatype_config, null: true
      t.string :preferred_handler, null: true
      t.text :handler_config, null: true
      t.integer :min_occurs, null: false, default: 1
      t.integer :max_occurs, null: true
      t.integer :creator, null: false
      t.datetime :date_created, null: false
      t.integer :changed_by, null: true
      t.datetime :date_changed, null: true
      t.boolean :retired, null: false, default: false
      t.integer :retired_by, null: true
      t.datetime :date_retired, null: true
      t.string :retire_reason, null: true
      t.string :uuid, null: false, limit: 38
    end
    add_index :location_attribute_types, :uuid, unique: true
    add_foreign_key :location_attribute_types, :users, column: :creator, primary_key: :user_id
    add_foreign_key :location_attribute_types, :users, column: :changed_by, primary_key: :user_id
    add_foreign_key :location_attribute_types, :users, column: :retired_by, primary_key: :user_id
  end
end
