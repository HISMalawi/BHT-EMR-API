# frozen_string_literal: true

module SpineService
  # This is the engine managing all spine reports.
  class ReportEngine
    REPORTS = {
      # 'DASHBOARD STATISTICS' => AetcService::Reports::Clinic::DashboardStats,
      'DIAGNOSIS' => SpineService::Reports::Clinic::DiagnosisReport,
      'ATTENDANCE' => SpineService::Reports::Clinic::AttendanceReport,
      'DASHBOARD' => SpineService::Reports::Clinic::DashboardReport
    }.freeze

    def find_report(start_date:, end_date:, name:, **kwargs)
      name = name&.upcase&.gsub('_', ' ') || kwargs[:type]&.upcase&.gsub('_', ' ')
      REPORTS[name].new(start_date: start_date, end_date: end_date, **kwargs).fetch_report
    end
  end
end
