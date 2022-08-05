class CreateVisitAttributeTypes < ActiveRecord::Migration[5.2]
  def change
    create_table :visit_attribute_type, id: false do |t|
      t.primary_key :visit_attribute_type_id
      t.string :name, null: false, limit: 255
      t.string :description, null: true, limit: 1024
      t.string :datatype, null: true, limit: 255
      t.text :datatype_config, null: true
      t.string :preferred_handler, null: true, limit: 255
      t.text :handler_config, null: true
      t.integer :min_occurs, null: false, default: 1
      t.integer :max_occurs, null: true
      t.integer :creator, null: false
      t.datetime :date_created, null: false
      t.integer :changed_by, null: true
      t.datetime :date_changed, null: true
      t.boolean :retired, default: false, null: false
      t.integer :retired_by, null: true
      t.datetime :date_retired, null: true
      t.string :retire_reason, null: true, limit: 255
      t.string :uuid, limit: 38, null: false
    end
    add_foreign_key :visit_attribute_type, :users, column: :creator, primary_key: :user_id
    add_foreign_key :visit_attribute_type, :users, column: :changed_by, primary_key: :user_id
  end
end
