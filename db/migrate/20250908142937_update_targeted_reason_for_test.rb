class UpdateTargetedReasonForTest < ActiveRecord::Migration[7.0]
  def change
    wrong_id = 3280 # Increase patient dose
    correct_id = ConceptName.find_by_name('Targeted').concept_id
    
    concept_id = ConceptName.find_by_name('Reason for test').concept_id

    Observation.where(
      concept_id: concept_id, value_coded: wrong_id
    ).update_all(value_coded: correct_id)
  end
end
