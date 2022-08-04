class CreateOrderGroups < ActiveRecord::Migration[5.2]
  def change
    create_table :order_group, id: false do |t|
      t.primary_key :order_group_id
      t.bigint :order_set_id, null: false
      t.integer :patient_id, null: false
      t.integer :encounter_id, null: false
      t.integer :creator, null: false
      t.datetime :date_created, null: false
      t.boolean :voided, default: false, null: false
      t.integer :voided_by, null: true
      t.datetime :date_voided, null: true
      t.string :void_reason, limit: 255, null: true
      t.datetime :changed_by, null: true
      t.string :uuid, limit: 38, null: false, unique: true
    end
    add_foreign_key :order_group, :order_set, column: :order_set_id, primary_key: :order_set_id
    add_foreign_key :order_group, :patient, column: :patient_id, primary_key: :patient_id
    add_foreign_key :order_group, :encounter, column: :encounter_id, primary_key: :encounter_id
    add_foreign_key :order_group, :users, column: :creator, primary_key: :user_id
    add_foreign_key :order_group, :users, column: :changed_by, primary_key: :user_id
    add_foreign_key :order_group, :users, column: :voided_by, primary_key: :user_id
  end
end
