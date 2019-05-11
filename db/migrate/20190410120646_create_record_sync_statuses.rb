class CreateRecordSyncStatuses < ActiveRecord::Migration[5.2]
  def change
    create_table :record_sync_statuses do |t|
      t.integer :record_type_id, null: false
      t.integer :record_id, null: false
      t.string :record_doc_id, null: false, unique: true
      t.time :created_at, null: false
      t.time :updated_at, null: false

      t.timestamps
    end
  end
end
