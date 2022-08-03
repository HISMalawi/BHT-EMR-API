class CreateVisits < ActiveRecord::Migration[5.2]
  def change
    create_table :visits do |t|
      t.integer :patient_id, null: false
      t.bigint :visit_type_id, null: false
      t.datetime :date_started, null: false
      t.datetime :date_stopped, null: true
      t.integer :indication_concept_id, null: false
      t.integer :location_id, null: false
      t.integer :creator, null: false
      t.datetime :date_created, null: false
      t.integer :changed_by, null: true
      t.datetime :date_changed, null: true
      t.boolean :voided, default: false
      t.integer :voided_by, null: true
      t.datetime :date_voided, null: true
      t.string :void_reason, null: true
      t.string :uuid, null: false, limit: 38
    end

    add_foreign_key :visits, :users, column: :creator, primary_key: :user_id
    add_foreign_key :visits, :users, column: :changed_by, primary_key: :user_id
    add_foreign_key :visits, :concept, column: :indication_concept_id, primary_key: :concept_id
    add_foreign_key :visits, :patient, column: :patient_id, primary_key: :patient_id
    add_foreign_key :visits, :visit_types, column: :visit_type_id, primary_key: :id
    add_foreign_key :visits, :location, column: :location_id, primary_key: :location_id
  end
end
