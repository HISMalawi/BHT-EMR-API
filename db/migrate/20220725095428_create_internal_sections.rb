# frozen_string_literal: true

class CreateInternalSections < ActiveRecord::Migration[5.2]
  def change
    create_table :internal_sections do |t|
      t.string :name, null: false
      t.integer :creator, null: false
      t.datetime :date_created, null: false
      t.integer :changed_by, null: true
      t.datetime :date_changed, null: true
      t.boolean :voided, default: false, null: false
      t.integer :voided_by, null: true
      t.datetime :date_voided, null: true
      t.string :void_reason, null: true

      t.timestamps
    end
    add_foreign_key :internal_sections, :users, column: :creator, primary_key: :user_id
    add_foreign_key :internal_sections, :users, column: :voided_by, primary_key: :user_id
  end
end
