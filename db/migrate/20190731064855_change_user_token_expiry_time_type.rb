class ChangeUserTokenExpiryTimeType < ActiveRecord::Migration[5.2]
  def up
    execute('ALTER TABLE users MODIFY COLUMN token_expiry_time DATETIME')
  end

  def down
    execute('ALTER TABLE users MODIFY COLUMN token_expiry_time DATE')
  end
end
