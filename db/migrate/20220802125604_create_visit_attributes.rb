class CreateVisitAttributes < ActiveRecord::Migration[5.2]
  def change
    create_table :visit_attribute, id: false do |t|
      t.primary_key :visit_attribute_id
      t.bigint :visit_id, null: false
      t.bigint :attribute_type_id, null: false
      t.text :value_reference, null: false
      t.string :uuid, null: false, limit: 38
      t.integer :creator, null: false
      t.datetime :date_created, null: false
      t.integer :changed_by, null: false
      t.boolean :voided, null: false, default: false
      t.integer :voided_by, null: false
      t.datetime :date_voided, null: false
      t.string :void_reason, null: false, limit: 255
    end
    add_foreign_key :visit_attribute, :users, column: :creator, primary_key: :user_id
    add_foreign_key :visit_attribute, :users, column: :changed_by, primary_key: :user_id
    add_foreign_key :visit_attribute, :visit, column: :visit_id, primary_key: :visit_id
    add_foreign_key :visit_attribute, :visit_attribute_type, column: :attribute_type_id, primary_key: :visit_attribute_type_id
  end
end
