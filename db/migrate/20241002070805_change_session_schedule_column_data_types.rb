class ChangeSessionScheduleColumnDataTypes < ActiveRecord::Migration[7.0]
  def change
    change_column :session_schedules, :start_date, :date
    change_column :session_schedules, :end_date, :date
    change_column :session_schedules, :voided, :boolean, default: false
  end
end
