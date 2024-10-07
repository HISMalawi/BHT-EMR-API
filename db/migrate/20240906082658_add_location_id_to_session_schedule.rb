class AddLocationIdToSessionSchedule < ActiveRecord::Migration[7.0]
  def change
    # Add the location_id column with a NOT NULL constraint
    add_column :session_schedules, :location_id, :integer, null: false
    
    # Rename the repeat column to repeat_type
    rename_column :session_schedules, :repeat, :repeat_type
  end
end
