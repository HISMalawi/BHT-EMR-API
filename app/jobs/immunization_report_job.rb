# app/jobs/immunization_report_job.rb
class ImmunizationReportJob < ApplicationJob
  queue_as :default

  sidekiq_options unique: :until_executed

  def perform(start_date, end_date, location_id)
    dashboard_stats = dashboard_service(start_date, end_date, location_id)
    dashboard_stats = dashboard_stats.data

    missed_visits = followup_service.fetch_missed_immunizations(location_id)

    dashboard_stats[:under_five_overdue] = missed_visits[:under_five_count]
    dashboard_stats[:over_five_overdue] = missed_visits[:over_five_count]
    dashboard_stats[:due_today_count] = missed_visits[:due_today_count]
    dashboard_stats[:due_this_week_count] = missed_visits[:due_this_week_count]
    dashboard_stats[:due_this_month_count] = missed_visits[:due_this_month_count]

    immunization_cache = ImmunizationCacheDatum.find_or_initialize_by(name: "dashboard_stats")
    immunization_cache.update!(value: dashboard_stats)


    immunization_cache = ImmunizationCacheDatum.find_or_initialize_by(name: "missed_immunizations")
    immunization_cache.update!(value: missed_visits)
  end

  private 

  def dashboard_service(start_date, end_date, location_id)
    ImmunizationService::Reports::Stats::ImmunizationDashboard.new(start_date: start_date,
                                                                   end_date: end_date, 
                                                                   location_id: location_id)
  end

  def followup_service
    ImmunizationService::FollowUp.new
  end


end
