# app/jobs/immunization_report_job.rb
class ImmunizationReportJob < ApplicationJob
  queue_as :default

  def perform(start_date, end_date, location_id)
    dashboard = ImmunizationService::Reports::Stats::ImmunizationDashboard.new(start_date: start_date, end_date: end_date, location_id: location_id)
    data = dashboard.data

    immunization_cache = ImmunizationCacheDatum.find_or_initialize_by(name: "dashboard_stats")
    immunization_cache.update!(value: data)
    
  end
end
