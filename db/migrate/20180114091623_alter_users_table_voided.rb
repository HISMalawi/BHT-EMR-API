# frozen_string_literal: true

# this migration alters the users table to change in the following columns:
# 1. voided to retired
# 2. void_reason to retire_reason
# 3. voided_by to retired_by
# 4. date_voided to date_retired

class AlterUsersTableVoided < ActiveRecord::Migration[5.2]
  def up
    rename_column :users, :voided, :retired unless column_exists?(:users, :retired)
    rename_column :users, :void_reason, :retire_reason unless column_exists?(:users, :retire_reason)
    rename_column :users, :voided_by, :retired_by unless column_exists?(:users, :retired_by)
    rename_column :users, :date_voided, :date_retired unless column_exists?(:users, :date_retired)
    add_column :users, :person_id, :integer unless column_exists?(:users, :person_id)
    add_column :users, :authentication_token, :string unless column_exists?(:users, :authentication_token)
    unless foreign_key_exists?(:users, :person_id)
        add_foreign_key :users, :person, column: :person_id, foreign_key: :person_id, primary_key: :person_id
    end
  end

  def down
    remove_foreign_key :users, :person
    remove_column :users, :person_id
    remove_column :users, :authentication_token
    rename_column :users, :retired, :voided
    rename_column :users, :retire_reason, :void_reason
    rename_column :users, :retired_by, :voided_by
    rename_column :users, :date_retired, :date_voided
  end
end
