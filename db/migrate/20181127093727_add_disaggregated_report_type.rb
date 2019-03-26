class AddDisaggregatedReportType < ActiveRecord::Migration[5.2]
  def up
    ReportType.create(name: 'cohort_disaggregated', creator: 1)
  end

  def down
    execute('SET FOREIGN_KEY_CHECKS=0')
    ReportType.find_by(name: 'cohort_disaggregated')&.destroy
    execute('SET FOREIGN_KEY_CHECKS=1')
  end
end
