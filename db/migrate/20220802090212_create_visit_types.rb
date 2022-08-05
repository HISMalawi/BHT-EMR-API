class CreateVisitTypes < ActiveRecord::Migration[5.2]
  def change
    create_table :visit_type, id: false do |t|
      t.primary_key :visit_type_id
      t.string :name, null: false, limit: 255
      t.string :description, null: true, limit: 1024
      t.integer :creator, null: false
      t.datetime :date_created, null: false
      t.integer :changed_by, null: true
      t.datetime :date_changed, null: true
      t.boolean :retired, null: false, default: false
      t.integer :retired_by, null: true
      t.datetime :date_retired, null: true
      t.string :retire_reason, null: true, limit: 255
      t.string :uuid, null: false, limit: 38, unique: true
    end
    add_foreign_key :visit_type, :users, column: :creator, primary_key: :user_id
    add_foreign_key :visit_type, :users, column: :changed_by, primary_key: :user_id
  end
end
