class AddValidationToRequiredSessionColumns < ActiveRecord::Migration[7.0]
  def change
    change_column_null :session_schedules, :start_date, false
    change_column_null :session_schedules, :end_date, false
    change_column_null :session_schedules, :session_name, false
    change_column_null :session_schedules, :session_type, false
    change_column_null :session_schedules, :repeat_type, false
  end
end
