class RemoveEncounterTypeIdFromEncounter < ActiveRecord::Migration[7.0]
  def change
    remove_column :encounter, :encounter_type_id, :integer      
  end
end
