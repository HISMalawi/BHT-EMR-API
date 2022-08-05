class CreateProviderAttributes < ActiveRecord::Migration[5.2]
  def change
    create_table :provider_attribute, id: false do |t|
      t.primary_key :provider_attribute_id
      t.bigint :provider_id, null: false
      t.bigint :attribute_type_id, null: false
      t.text :value_reference, null: true
      t.string :uuid, limit: 38, null: false, unique: true
      t.integer :creator, null: false
      t.datetime :date_created, null: false
      t.integer :changed_by, null: false
      t.datetime :date_changed, null: false
      t.boolean :voided, null: false, default: false
      t.integer :voided_by, null: true
      t.datetime :date_voided, null: true
      t.string :void_reason, null: true, limit: 255
    end
    add_foreign_key :provider_attribute, :provider, column: :provider_id, primary_key: :provider_id
    add_foreign_key :provider_attribute, :provider_attribute_type, column: :attribute_type_id, primary_key: :provider_attribute_type_id
    add_foreign_key :provider_attribute, :users, column: :creator, primary_key: :user_id
    add_foreign_key :provider_attribute, :users, column: :changed_by, primary_key: :user_id
    add_foreign_key :provider_attribute, :users, column: :voided_by, primary_key: :user_id
  end
end
