class CreateNotificationTrackerUserActivities < ActiveRecord::Migration[5.2]
  def self.up
    create_table  :notification_tracker_user_activities, :id => false do |t|
      t.integer   :id,                    :null => false
      t.integer   :user_id,               :null => false
      t.datetime  :login_datetime,        :null => false
      t.text      :selected_activities
    end
    execute "ALTER TABLE `notification_tracker_user_activities` CHANGE COLUMN `id` `id` INT(11) NOT NULL AUTO_INCREMENT, ADD PRIMARY KEY (`id`);"
  end

  def self.down
    drop_table :notification_tracker_user_activities
  end
end
