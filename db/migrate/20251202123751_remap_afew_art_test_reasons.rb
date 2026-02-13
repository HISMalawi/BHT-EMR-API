class RemapAfewArtTestReasons < ActiveRecord::Migration[7.0]
  def change
    id_remap = {
      1345 => 10230, # Confirmed to Confirmatory
      6368 => 10254, # Status to Stat
      9144 => 10228 # Missing to Repeat / Missing
    }

    concept_id = ConceptName.find_by_name('Reason for test').concept_id
  
    id_remap.each do |wrong_id, correct_id|
      Observation.where(
        concept_id: concept_id, value_coded: wrong_id
      ).update_all(value_coded: correct_id)
    end
  end
end
