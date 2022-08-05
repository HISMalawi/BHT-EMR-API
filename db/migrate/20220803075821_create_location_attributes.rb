class CreateLocationAttributes < ActiveRecord::Migration[5.2]
  def change
    create_table :location_attribute, id: false do |t|
      t.primary_key :location_attribute_id
      t.integer :location_id, null: false
      t.bigint :attribute_type_id, null: false
      t.text :value_reference, null: true
      t.string :uuid, null: false, limit: 38, unique: true
      t.integer :creator, null: false
      t.datetime :date_created, null: false
      t.integer :changed_by, null: true
      t.datetime :date_changed, null: true
      t.boolean :voided, default: false, null: false
      t.integer :voided_by, null: true
      t.datetime :date_voided, null: true
      t.string :void_reason, null: true, limit: 255
    end
    add_foreign_key :location_attribute, :location, column: :location_id, primary_key: :location_id
    add_foreign_key :location_attribute, :location_attribute_type, column: :attribute_type_id, primary_key: :location_attribute_type_id
    add_foreign_key :location_attribute, :users, column: :creator, primary_key: :user_id
    add_foreign_key :location_attribute, :users, column: :changed_by, primary_key: :user_id
    add_foreign_key :location_attribute, :users, column: :voided_by, primary_key: :user_id
  end
end
