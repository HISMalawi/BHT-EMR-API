class AddIndexesToRecordSyncStatuses < ActiveRecord::Migration[5.2]
  def up
    execute <<~SQL
      ALTER TABLE `record_sync_statuses`
        ADD INDEX `idx_record_type_id` (record_type_id),
        ADD INDEX `idx_record_id` (record_id),
        ADD INDEX `idx_database` (`database`),
        ADD INDEX `idx_database_record_type_id` (record_type_id, record_id, `database`)
    SQL
  end

  def down
    execute <<~SQL
      ALTER TABLE `record_sync_statuses`
        DROP INDEX `idx_record_type_id`,
        DROP INDEX `idx_record_id`,
        DROP INDEX `idx_database`,
        DROP INDEX `idx_database_record_type_id`
    SQL
  end
end
