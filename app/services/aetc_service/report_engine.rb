# frozen_string_literal: true

module AetcService
  # This is the engine managing all radiology reports.
  class ReportEngine
    REPORT_NAMES = {
      'DASHBOARD STATISTICS' => AetcService::Reports::Clinic::DashboardStats,
      'DIAGNOSIS REPORT' => AetcService::Reports::Clinic::DiagnosisReport,
    }.freeze

    def reports(start_date, end_date, name, **kwargs)
      name = name.upcase
      REPORT_NAMES[name].new(start_date: start_date, end_date: end_date, **kwargs).fetch_report
    end

    def dashboard_stats(date)
      REPORT_NAMES['DASHBOARD STATISTICS'].new(start_date: date, end_date: date).fetch_report
    end
  end
end
