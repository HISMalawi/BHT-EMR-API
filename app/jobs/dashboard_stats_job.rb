class DashboardStatsJob < ApplicationJob

  queue_as :default

  def perform
    dashboard_stats = ImmunizationCacheDatum.where(:name => "dashboard_stats")
    missed_visits = ImmunizationCacheDatum.where(:name=>"missed_immunizations")

    data = {
        dashboard_stats: dashboard_stats,
        missed_visits: missed_visits
    }

    ActionCable.server.broadcast('immunization_report_channel', data)
  end

end