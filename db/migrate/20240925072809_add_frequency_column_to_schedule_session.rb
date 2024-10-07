class AddFrequencyColumnToScheduleSession < ActiveRecord::Migration[7.0]
  def change
    add_column :session_schedules, :frequency, :integer, default: 0
    remove_column :session_schedules, :target
  end
end
