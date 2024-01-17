class CohortDrillDown < ActiveRecord::Migration[5.2]
  def change
    create_table :cohort_drill_down do |t|
      t.integer   :reporting_report_design_resource_id, null: false
      t.integer   :patient_id, null: false
    end
  end

  def self.down
    drop_table :cohort_drill_down
  end
end
