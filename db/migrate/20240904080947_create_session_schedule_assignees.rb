class CreateSessionScheduleAssignees < ActiveRecord::Migration[7.0]
  def change
    create_table :session_schedule_assignees, id: false, primary_key: :schedule_assignee_id do |t|
      t.integer :schedule_assignee_id, null: false, primary_key: true
      t.integer :session_schedule_id, presence: true
      t.integer :user_id, presence: true
      t.integer :voided, default: 0, limit: 1
      t.integer :voided_by
      t.datetime :date_voided
      t.timestamps
    end
  end
end
