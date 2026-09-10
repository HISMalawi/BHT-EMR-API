# frozen_string_literal: true

class CreateStreamingLedgers < ActiveRecord::Migration[8.0]
  def change
    create_table :streaming_ledgers do |t|
      t.string :uuid, null: false
      t.string :stream_key, null: false
      t.bigint :patient_id, null: false
      t.integer :program_id, null: false
      t.date :stream_date, null: false
      t.string :payload_hash
      t.string :status, null: false, default: 'queued'
      t.integer :response_code
      t.text :error_message
      t.datetime :sent_at
      t.datetime :acknowledged_at
      t.integer :retry_count, null: false, default: 0

      t.timestamps
    end

    add_index :streaming_ledgers, :uuid, unique: true
    add_index :streaming_ledgers, :stream_key, unique: true
    add_index :streaming_ledgers, %i[patient_id program_id stream_date]
    add_index :streaming_ledgers, :status
  end
end
