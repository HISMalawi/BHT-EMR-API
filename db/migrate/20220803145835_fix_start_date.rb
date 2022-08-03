class FixStartDate < ActiveRecord::Migration[5.2]
  def self.up
    rename_column :orders, :start_date, :date_activated
  end

  def self.down
    rename_column :orders, :date_activated, :start_date
  end
end
