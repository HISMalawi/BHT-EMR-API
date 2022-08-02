class CreateProviderAttributes < ActiveRecord::Migration[5.2]
  def change
    create_table :provider_attributes do |t|
      t.bigint :provider_id, null: false
      t.bigint :attribute_type_id, null: false
      t.text :value_reference, null: true
      t.string :uuid, limit: 36, null: false
      t.integer :creator, null: false
      t.datetime :date_created, null: false
      t.integer :changed_by, null: false
      t.datetime :date_changed, null: false
      t.boolean :voided, null: false, default: false
      t.integer :voided_by, null: true
      t.datetime :date_voided, null: true
      t.string :void_reason, null: true
    end
    add_foreign_key :provider_attributes, :providers, column: :provider_id, primary_key: :id
    add_foreign_key :provider_attributes, :provider_attribute_types, column: :attribute_type_id, primary_key: :id
    add_foreign_key :provider_attributes, :users, column: :creator, primary_key: :user_id
    add_foreign_key :provider_attributes, :users, column: :changed_by, primary_key: :user_id
    add_foreign_key :provider_attributes, :users, column: :voided_by, primary_key: :user_id
    add_index :provider_attributes, :uuid, unique: true
  end
end
