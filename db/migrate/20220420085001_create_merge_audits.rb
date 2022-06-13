# frozen_string_literal: true

# this creates MergeAudits table
class CreateMergeAudits < ActiveRecord::Migration[5.2]
  def change
    create_table :merge_audits do |t|
      t.integer :primary_id, null: false
      t.integer :secondary_id, null: false
      t.string :merge_type, null: false
      t.bigint :secondary_previous_merge_id, null: true
      t.integer :creator, null: false
      t.boolean :voided, null: false, default: false
      t.integer :voided_by, null: true
      t.datetime :date_voided, null: true
      t.string :void_reason, null: true

      t.timestamps
    end
    add_foreign_key :merge_audits, :patient, column: :primary_id, primary_key: :patient_id
    add_foreign_key :merge_audits, :patient, column: :secondary_id, primary_key: :patient_id
    add_foreign_key :merge_audits, :users, column: :creator, primary_key: :user_id
    add_foreign_key :merge_audits, :users, column: :voided_by, primary_key: :user_id
    add_foreign_key :merge_audits, :merge_audits, column: :secondary_previous_merge_id
  end
end
