class AddReportDatetimeToReport < ActiveRecord::Migration[5.2]
  def change
    add_column :reporting_report_design, :report_datetime, :datetime, default: 'NOW()'
  end
end
