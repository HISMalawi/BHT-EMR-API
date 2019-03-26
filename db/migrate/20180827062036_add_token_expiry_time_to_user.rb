class AddTokenExpiryTimeToUser < ActiveRecord::Migration[5.2]
  def change
    execute 'ALTER TABLE users MODIFY COLUMN date_created TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP()'
    add_column :users, :token_expiry_time, :date
  end
end
