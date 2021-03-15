class CreateNotificationTrackers < ActiveRecord::Migration[5.2]
  def self.up
    create_table  :notification_tracker,  :id => false do |t|
      t.integer   :tracker_id,            :null => false
      t.string    :notification_name,     :null => false
      t.text      :description
      t.string    :notification_response, :null => false
      t.datetime  :notification_datetime, :null => false
      t.integer   :patient_id,            :null => false
      t.integer   :user_id,               :null => false
    end
    execute "ALTER TABLE `notification_tracker` CHANGE COLUMN `tracker_id` `tracker_id` INT(11) NOT NULL AUTO_INCREMENT, ADD PRIMARY KEY (`tracker_id`);"
  end

  def self.down
    drop_table :notification_tracker
  end
end
