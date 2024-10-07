class SessionScheduleMapping < ActiveRecord::Migration[7.0]
  def change
    add_foreign_key :session_schedule_assignees, :users,
    column: :user_id, primary_key: :user_id
  
    add_foreign_key :session_schedule_assignees, :session_schedules,
    column: :session_schedule_id, primary_key: :session_schedule_id
  
    add_foreign_key :session_schedule_vaccines, :drug, 
    column: :drug_id, primary_key: :drug_id
  
    add_foreign_key :session_schedule_vaccines, :session_schedules,
    column: :session_schedule_id, primary_key: :session_schedule_id
  end
end
