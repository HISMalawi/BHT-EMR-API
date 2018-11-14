class AddCohortReportType < ActiveRecord::Migration[5.2]
  def up
    execute("INSERT INTO report_def (name, creator) VALUES ('Cohort', 1)")
  end

  def down
    execute("DELETE FROM report_def WHERE name LIKE 'Cohort'")
  end
end
