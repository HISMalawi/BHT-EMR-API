class RemoveDrugPrefixFromPharmacyEventTypes < ActiveRecord::Migration[5.2]
  NAMES_MAPPING = {
    'Drugs added' => 'Added',
    'Drugs removed' => 'Removed',
    'Drugs edited' => 'Edited'
  }

  def up
    NAMES_MAPPING.each do |old_name, new_name|
      event = PharmacyEncounterType.find_by(name: old_name)
      next unless event

      event.update_columns(name: new_name)
    end
  end

  def down
    NAMES_MAPPING.each do |old_name, new_name|
      event = PharmacyEncounterType.find_by(name: new_name)
      next unless event

      event.update_columns(name: old_name)
    end
  end
end
