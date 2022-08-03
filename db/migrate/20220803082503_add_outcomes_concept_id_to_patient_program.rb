class AddOutcomesConceptIdToPatientProgram < ActiveRecord::Migration[5.2]
  def change
    add_column :patient_program, :outcomes_concept_id, :integer, null: true
    add_foreign_key :patient_program, :concept, column: :outcomes_concept_id, primary_key: :concept_id
  end
end
