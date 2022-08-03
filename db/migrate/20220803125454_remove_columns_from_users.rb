class RemoveColumnsFromUsers < ActiveRecord::Migration[5.2]
  def change
    remove_column :users, :authentication_token, :string
    remove_column :users, :token_expiry_time, :datetime
    remove_column :users, :deactivated_on, :datetime
  end
end
