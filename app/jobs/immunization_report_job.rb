# app/jobs/immunization_report_job.rb
class ImmunizationReportJob < ApplicationJob
  queue_as :default

  def perform(start_date, end_date, location_id)
    dashboard_stats = dashboard_service(start_date, end_date, location_id)
    dashboard_stats = dashboard_stats.data

    missed_visits = followup_service.fetch_missed_immunizations(location_id)

    dashboard_stats[:under_five_overdue] = missed_visits[:under_five_count]
    dashboard_stats[:over_five_overdue] = missed_visits[:over_five_count]
    dashboard_stats[:due_today_count] = missed_visits[:due_today_count]
    dashboard_stats[:due_this_week_count] = missed_visits[:due_this_week_count]
    dashboard_stats[:due_this_month_count] = missed_visits[:due_this_month_count]

    update_cache('dashboard_stats', location_id, dashboard_stats)
    update_cache('missed_immunizations', location_id, missed_visits)
    
    ActionCable.server.broadcast("immunization_report_channel_#{location_id}", dashboard_stats)
  end

  private 
  
  def dashboard_service(start_date, end_date, location_id)
    ImmunizationService::Reports::Stats::ImmunizationDashboard.new(start_date:,
                                                                   end_date:,
                                                                   location_id:)
  end

  def followup_service
    ImmunizationService::FollowUp.new
  end

  def update_cache(name, location_id, value)
    cache_id = ImmunizationCacheDatum.where(name:, location_id:)

    if cache_id.blank?
      ImmunizationCacheDatum.create(name:, location_id:, value:)
    else
      # For some reason the updated_at Field is not being updated after a run so will figure it out someday.
      cache_id.update_all(value:, updated_at: Time.now)
    end
  end
end
