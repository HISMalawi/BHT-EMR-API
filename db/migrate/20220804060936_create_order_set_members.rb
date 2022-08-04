class CreateOrderSetMembers < ActiveRecord::Migration[5.2]
  def change
    create_table :order_set_member, id: false do |t|
      t.primary_key :order_set_member_id
      t.integer :order_type, null: false
      t.text :order_template, null: true
      t.string :order_template_type, limit: 1024, null: true
      t.bigint :order_set_id, null: false
      t.integer :sequence_number, null: false
      t.integer :concept_id, null: false
      t.integer :creator, null: false
      t.datetime :date_created, null: false
      t.boolean :retired, default: false, null: false
      t.integer :retired_by, null: true
      t.datetime :date_retired, null: true
      t.string :retire_reason, limit: 255, null: true
      t.integer :changed_by, null: true
      t.datetime :date_changed, null: true
      t.string :uuid, limit: 38, null: false, unique: true
    end
    add_foreign_key :order_set_member, :order_set, column: :order_set_id, primary_key: :order_set_id
    add_foreign_key :order_set_member, :concept, column: :concept_id, primary_key: :concept_id
    add_foreign_key :order_set_member, :users, column: :creator, primary_key: :user_id
    add_foreign_key :order_set_member, :users, column: :changed_by, primary_key: :user_id
    add_foreign_key :order_set_member, :users, column: :retired_by, primary_key: :user_id
    add_foreign_key :order_set_member, :order_type, column: :order_type, primary_key: :order_type_id
  end
end
