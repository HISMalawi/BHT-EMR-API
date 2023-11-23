class CreateLocationTagWorkstationLocation < ActiveRecord::Migration[5.2]
  def self.up
    # Check if the location already exists before inserting it to avoid duplicates
    if LocationTag.find_by_name('workstation location').blank?
      execute "INSERT INTO `location_tag` (`name`, `description`, `creator`, `date_created`, `retired`, `retired_by`, `date_retired`, `retire_reason`, `uuid`)
               VALUES ('workstation location', NULL, 1, '2011-04-27 14:58:31', 0, NULL, NULL, NULL, '');"
    end rescue nil
  end

  def self.down
  end
end
