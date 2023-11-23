class AddDisaggregatedCohortReport < ActiveRecord::Migration[5.2]
  def up
    ReportType.create(name: 'disaggregated_cohort', creator: User.first&.user_id)
  end

  def down
    report_type = ReportType.find_by_name('disaggregated_cohort')
    report_type&.destroy
  end
end

