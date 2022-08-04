class CreateOrderFrequencies < ActiveRecord::Migration[5.2]
  def change
    create_table :order_frequency, id: false do |t|
      t.primary_key :order_frequency_id
      t.integer :concept_id, null: false
      t.decimal :frequency_per_day, null: true, precision: 8, scale: 2
      t.integer :creator, null: false
      t.datetime :date_created, null: false
      t.boolean :retired, default: false, null: false
      t.integer :retired_by, null: true
      t.datetime :date_retired, null: true
      t.string :retire_reason, limit: 255, null: true
      t.integer :changed_by, null: true
      t.datetime :date_changed, null: true
      t.string :uuid, null: false, limit: 38
    end
    add_foreign_key :order_frequency, :concept, column: :concept_id, primary_key: :concept_id
    add_foreign_key :order_frequency, :users, column: :creator, primary_key: :user_id
    add_foreign_key :order_frequency, :users, column: :changed_by, primary_key: :user_id
    add_foreign_key :order_frequency, :users, column: :retired_by, primary_key: :user_id
  end
end
