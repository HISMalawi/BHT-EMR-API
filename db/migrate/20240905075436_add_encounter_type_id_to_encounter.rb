class AddEncounterTypeIdToEncounter < ActiveRecord::Migration[7.0]
  def change
    add_column :encounter, :encounter_type_id, :integer  
  end
end
