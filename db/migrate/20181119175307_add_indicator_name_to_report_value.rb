# frozen_string_literal: true

class AddIndicatorNameToReportValue < ActiveRecord::Migration[5.2]
  def up
    add_column :reporting_report_design_resource, :indicator_name, :string unless column_exists?(:reporting_report_design_resource, :indicator_name)
    add_column :reporting_report_design_resource, :indicator_short_name, :string unless column_exists?(:reporting_report_design_resource, :indicator_short_name)
  end

  def down
    remove_column :reporting_report_design_resource, :indicator_name
    remove_column :reporting_report_design_resource, :indicator_short_name
  end
end
