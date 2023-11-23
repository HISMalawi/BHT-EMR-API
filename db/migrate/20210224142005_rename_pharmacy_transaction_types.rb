class RenamePharmacyTransactionTypes < ActiveRecord::Migration[5.2]
  EVENT_NAME_MAPPING = {
    'New deliveries' => 'Drugs added',
    'Tins removed' => 'Drugs removed',
    'Edited stock' => 'Drugs edited'
  }.freeze

  def up
    EVENT_NAME_MAPPING.each do |old_event_name, new_event_name|
      puts "Renaming pharmacy event: #{old_event_name} => #{new_event_name}"

      event_type = PharmacyEncounterType.find_by_name(old_event_name)
      unless event_type
        puts "Pharmacy event `#{old_event_name}` not found"
        next
      end

      event_type.update_columns(name: new_event_name)
    end
  end

  def down
    EVENT_NAME_MAPPING.each do |old_event_name, new_event_name|
      puts "Renaming pharmacy event: #{new_event_name} => #{old_event_name}"

      event_type = PharmacyEncounterType.find_by_name(new_event_name)
      unless event_type
        puts "Pharmacy event `#{new_event_name}` not found"
        next
      end

      event_type.update_columns(name: old_event_name)
    end
  end
end
