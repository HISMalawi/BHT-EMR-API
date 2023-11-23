class AddDatabaseToRecordSyncStatus < ActiveRecord::Migration[5.2]
  def change
    add_column :record_sync_statuses, :database, :string
  end
end
