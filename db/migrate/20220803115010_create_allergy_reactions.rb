class CreateAllergyReactions < ActiveRecord::Migration[5.2]
  def change
    create_table :allergy_reaction, id: false do |t|
      t.primary_key :allergy_reaction_id
      t.bigint :allergy_id, null: false
      t.integer :reaction_concept_id, null: false
      t.string :reaction_non_coded, null: true, limit: 255
      t.string :uuid, null: false, limit: 38, unique: true
    end
    add_foreign_key :allergy_reaction, :allergy, column: :allergy_id, primary_key: :allergy_id
    add_foreign_key :allergy_reaction, :concept, column: :reaction_concept_id, primary_key: :concept_id
  end
end
