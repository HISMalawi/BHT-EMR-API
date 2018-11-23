class AddIndicatorNameToReportValue < ActiveRecord::Migration[5.2]
  def change
    add_column :reporting_report_design_resource, :indicator_name, :string
    add_column :reporting_report_design_resource, :indicator_short_name, :string
  end
end
