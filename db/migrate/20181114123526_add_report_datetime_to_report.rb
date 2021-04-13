class AddReportDatetimeToReport < ActiveRecord::Migration[5.2]
  def change
    add_column :reporting_report_design, :start_date, :date
    add_column :reporting_report_design, :end_date, :date
  end
end
