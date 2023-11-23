class AddReportDatetimeToReport < ActiveRecord::Migration[5.2]
  def up
    add_column :reporting_report_design, :start_date, :date unless column_exists?(:reporting_report_design, :start_date)
    add_column :reporting_report_design, :end_date, :date unless column_exists?(:reporting_report_design, :end_date)
  end

  def down
    remove_column :reporting_report_design, :start_date
    remove_column :reporting_report_design, :end_date
  end
end
