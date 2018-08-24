class AddTockenExpirelyTimeToUsersTable < ActiveRecord::Migration[5.2]
  def self.up
  	 add_column :users, :tocken_expirely, :datetime
  end
  def self.down
  	remove_column :users, :tocken_expirely
  end
end
