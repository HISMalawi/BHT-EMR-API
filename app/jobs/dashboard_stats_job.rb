class DashboardStatsJob < ApplicationJob

  queue_as :default

  def perform
    dashboard_stats = ImmunizationCacheDatum.where(:name => "dashboard_stats").pick(:value)

    ActionCable.server.broadcast('immunization_report_channel', dashboard_stats)
  end

end