class AddIndicatorNameToReportResource < ActiveRecord::Migration[5.2]
  def change
    add_column :reporting_report_design_resource, :indicator_name, :string, null: false
    add_column :reporting_report_design_resource, :indicator_short_name, :string, null: true
  end
end
