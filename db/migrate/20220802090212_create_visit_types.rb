class CreateVisitTypes < ActiveRecord::Migration[5.2]
  def change
    create_table :visit_types do |t|
      t.string :name, null: false
      t.string :description, null: true
      t.integer :creator, null: false
      t.datetime :date_created, null: false
      t.integer :changed_by, null: true
      t.datetime :date_changed, null: true
      t.boolean :retired, null: false, default: false
      t.integer :retired_by, null: true
      t.datetime :date_retired, null: true
      t.string :retire_reason, null: true
      t.string :uuid, null: false, limit: 36
    end
    add_foreign_key :visit_types, :users, column: :creator, primary_key: :user_id
    add_foreign_key :visit_types, :users, column: :changed_by, primary_key: :user_id
  end
end
