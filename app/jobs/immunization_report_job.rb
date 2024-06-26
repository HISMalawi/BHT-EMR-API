# app/jobs/immunization_report_job.rb
class ImmunizationReportJob < ApplicationJob
  queue_as :default

  def perform(start_date, end_date)
    dashboard = ImmunizationService::Reports::Stats::ImmunizationDashboard.new(start_date: start_date, end_date: end_date)
    data = dashboard.data

    ActionCable.server.broadcast('immunization_report_channel', data)
  end
end
