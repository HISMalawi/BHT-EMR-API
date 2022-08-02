class CreateVisitAttributeTypes < ActiveRecord::Migration[5.2]
  def change
    create_table :visit_attribute_types do |t|
      t.string :name, null: false
      t.string :description, null: true
      t.string :datatype
      t.text :datatype_config
      t.string :preferred_handler, null: false
      t.text :handler_config, null: true
      t.integer :min_occurs, default: 1
      t.integer :max_occurs, default: 1
      t.integer :creator, null: false
      t.datetime :date_created, null: false
      t.integer :changed_by, null: true
      t.datetime :date_changed, null: true
      t.boolean :retired, default: false, null: false
      t.integer :retired_by, null: true
      t.datetime :date_retired, null: true
      t.string :retire_reason, null: true
      t.string :uuid, limit: 36, null: false
    end
    add_foreign_key :visit_attribute_types, :users, column: :creator, primary_key: :user_id
    add_foreign_key :visit_attribute_types, :users, column: :changed_by, primary_key: :user_id
  end
end
