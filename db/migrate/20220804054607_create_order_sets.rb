class CreateOrderSets < ActiveRecord::Migration[5.2]
  def change
    create_table :order_set, id: false do |t|
      t.primary_key :order_set_id
      t.string :operator, null: false, limit: 50
      t.string :name, null: false, limit: 255
      t.string :description, limit: 1000, null: true
      t.integer :creator, null: false
      t.datetime :date_created, null: false
      t.boolean :retired, default: false, null: false
      t.integer :retired_by, null: true
      t.datetime :date_retired, null: true
      t.string :retire_reason, limit: 255, null: true
      t.integer :changed_by, null: true
      t.datetime :date_changed, null: true
      t.string :uuid, null: false, limit: 38, unique: true
    end
    add_foreign_key :order_set, :users, column: :creator, primary_key: :user_id
    add_foreign_key :order_set, :users, column: :changed_by, primary_key: :user_id
    add_foreign_key :order_set, :users, column: :retired_by, primary_key: :user_id
  end
end
