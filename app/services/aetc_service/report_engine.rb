# frozen_string_literal: true

module AetcService
  # This is the engine managing all radiology reports.
  class ReportEngine
    REPORT_NAMES = {
      'DASHBOARD STATISTICS' => AetcService::Reports::Clinic::DashboardStats
    }.freeze

    def reports(start_date, end_date, name)
      name = name.upcase
      REPORT_NAMES[name].new(start_date: start_date, end_date: end_date).data
    end

    def dashboard_stats(date)
      REPORT_NAMES['DASHBOARD STATISTICS'].new(start_date: date, end_date: date).fetch_report
    end
  end
end
