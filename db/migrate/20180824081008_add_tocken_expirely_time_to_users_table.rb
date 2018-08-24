class AddTockenExpirelyTimeToUsersTable < ActiveRecord::Migration[5.2]
  def self.up
  	 add_column :users, :token_expiry_time, :datetime
  end
  def self.down
  	remove_column :users, :token_expiry_time
  end
end
