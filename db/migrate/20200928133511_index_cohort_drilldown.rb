class IndexCohortDrilldown < ActiveRecord::Migration[5.2]
  def up
    ActiveRecord::Base.connection.execute <<~SQL
      CREATE INDEX drilldown_report_value ON cohort_drill_down (reporting_report_design_resource_id)
    SQL
  end

  def down
    ActiveRecord::Base.connection.execute <<~SQL
      DROP INDEX drilldown_report_value ON cohort_drill_down
    SQL
  end
end
