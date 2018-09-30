class AddTokenExpiryTimeToUser < ActiveRecord::Migration[5.2]
  def change
    execute 'ALTER TABLE users MODIFY COLUMN date_created DATETIME NOT NULL DEFAULT NOW()'
    add_column :users, :token_expiry_time, :date
  end
end
