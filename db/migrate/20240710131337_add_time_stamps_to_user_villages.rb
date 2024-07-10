class AddTimeStampsToUserVillages < ActiveRecord::Migration[7.0]
  def change
    add_timestamps :user_villages, null: true # Adding null: true to acoid issues with existing records

    # Backfill existing records with created_at and updated_at if needed
    # Setting the created_at and updated_at columns to the current time
    long_ago = DateTime.new(2000, 1, 1)
    UserVillage.update_all(created_at: long_ago, updated_at: long_ago)

    # Change null constraint if needed
    change_column_null :user_villages, :created_at, false
    change_column_null :user_villages, :updated_at, false
  end
end
