class CreateLocationAttributes < ActiveRecord::Migration[5.2]
  def change
    create_table :location_attributes do |t|
      t.integer :location_id, null: false
      t.bigint :attribute_type_id, null: false
      t.text :value_reference, null: true
      t.string :uuid, null: false, limit: 38
      t.integer :creator, null: false
      t.datetime :date_created, null: false
      t.integer :changed_by, null: true
      t.datetime :date_changed, null: true
      t.boolean :voided, default: false, null: false
      t.integer :voided_by, null: true
      t.datetime :date_voided, null: true
      t.string :void_reason, null: true
    end
    add_index :location_attributes, :uuid, unique: true
    add_foreign_key :location_attributes, :location, column: :location_id, primary_key: :location_id
    add_foreign_key :location_attributes, :location_attribute_types, column: :attribute_type_id, primary_key: :id
    add_foreign_key :location_attributes, :users, column: :creator, primary_key: :user_id
    add_foreign_key :location_attributes, :users, column: :changed_by, primary_key: :user_id
    add_foreign_key :location_attributes, :users, column: :voided_by, primary_key: :user_id
  end
end
