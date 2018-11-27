class AddReportStartAndEndDate < ActiveRecord::Migration[5.2]
  def up
    add_column :reporting_report_design, :start_date, :date
    add_column :reporting_report_design, :end_date, :date
    execute "UPDATE reporting_report_design SET start_date = '1900-01-01',
                                                end_date = DATE(report_datetime)"
    remove_column :reporting_report_design, :report_datetime
  end

  def down
    add_column :reporting_report_design, :report_datetime, :datetime, default: 'NOW()'
    execute 'UPDATE reporting_report_design SET report_datetime = end_date'
    remove_column :reporting_report_design, :start_date
    remove_column :reporting_report_design, :end_date
  end
end
