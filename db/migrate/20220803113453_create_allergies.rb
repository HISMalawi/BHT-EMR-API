class CreateAllergies < ActiveRecord::Migration[5.2]
  def change
    create_table :allergy, id: false do |t|
      t.primary_key :allergy_id
      t.integer :patient_id, null: false
      t.integer :severity_concept_id, null: true
      t.integer :coded_allergen, null: false
      t.string :non_coded_allergen, null: true
      t.string :allergen_type, null: false
      t.text :comment, null: true, limit: 1024
      t.integer :creator, null: false
      t.datetime :date_created, null: false
      t.integer :changed_by, null: true
      t.datetime :date_changed, null: true
      t.boolean :voided, null: false, default: false
      t.integer :voided_by, null: true
      t.datetime :date_voided, null: true
      t.string :void_reason, null: true, limit: 255
      t.string :uuid, null: false, limit: 38, unique: true
    end
    add_foreign_key :allergy, :patient, column: :patient_id, primary_key: :patient_id
    add_foreign_key :allergy, :concept, column: :severity_concept_id, primary_key: :concept_id
    add_foreign_key :allergy, :concept, column: :coded_allergen, primary_key: :concept_id
    add_foreign_key :allergy, :users, column: :creator, primary_key: :user_id
    add_foreign_key :allergy, :users, column: :changed_by, primary_key: :user_id
    add_foreign_key :allergy, :users, column: :voided_by, primary_key: :user_id
  end
end
