class AddTokenExpiryTimeToUser < ActiveRecord::Migration[5.2]
  def change
    add_column :users, :token_expiry_time, :date
  end
end
