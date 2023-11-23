class AddMonthlyReport < ActiveRecord::Migration[5.2]
  def up
    ReportType.create(name: 'monthly', creator: User.first&.user_id)
  end

  def down
    report_type = ReportType.find_by_name('monthly')
    report_type&.destroy
  end
end
