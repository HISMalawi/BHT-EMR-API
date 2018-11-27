# frozen_string_literal: true

class AddCohortReportType < ActiveRecord::Migration[5.2]
  def up
    ReportType.create(name: 'Cohort', creator: User.first&.user_id)
  end

  def down
    report_type = ReportType.find_by_name('Cohort')
    report_type&.destroy
  end
end
