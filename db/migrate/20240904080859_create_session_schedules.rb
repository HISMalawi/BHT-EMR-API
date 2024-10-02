class CreateSessionSchedules < ActiveRecord::Migration[7.0]
  def change
    create_table :session_schedules, id: false, primary_key: :session_schedule_id do |t|
      t.integer :session_schedule_id, null: false, primary_key: true
      t.string  :start_date, presence: true
      t.string  :end_date, presence: true
      t.string  :session_type, presence: true
      t.string  :repeat, presence: true
      t.string  :target, presence: true
      t.integer :voided, default: 0, limit: 1
      t.integer :voided_by
      t.datetime :date_voided
      t.string :void_reason, limit: 225
      t.timestamps
    end
  end
end