# frozen_string_literal: true

# this migration alters the users table to change in the following columns:
# 1. voided to retired
# 2. void_reason to retire_reason
# 3. voided_by to retired_by
# 4. date_voided to date_retired

class AlterUsersTableVoided < ActiveRecord::Migration[5.2]
    def up
        unless column_exists?(:users, :retired)
            rename_column :users, :voided, :retired
        end
        unless column_exists?(:users, :retire_reason)
            rename_column :users, :void_reason, :retire_reason
        end
        unless column_exists?(:users, :retired_by)
            rename_column :users, :voided_by, :retired_by
        end
        unless column_exists?(:users, :date_retired)
            rename_column :users, :date_voided, :date_retired
        end
    end

    def down
        rename_column :users, :retired, :voided
        rename_column :users, :retire_reason, :void_reason
        rename_column :users, :retired_by, :voided_by
        rename_column :users, :date_retired, :date_voided
    end
end