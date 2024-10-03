class AddSessionNameColumn < ActiveRecord::Migration[7.0]
  def change
    add_column :session_schedules, :session_name, :string, null: false
  end
end
