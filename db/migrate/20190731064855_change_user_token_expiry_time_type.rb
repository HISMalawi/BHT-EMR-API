# frozen_string_literal: true

class ChangeUserTokenExpiryTimeType < ActiveRecord::Migration[5.2]
  def up
    execute('ALTER TABLE users MODIFY COLUMN token_expiry_time DATETIME') if column_exists?(:users, :token_expiry_time)
  end

  def down
    execute('ALTER TABLE users MODIFY COLUMN token_expiry_time DATE') if column_exists?(:users, :token_expiry_time)
  end
end
