# frozen_string_literal: true

module PatientRegistrationService
  # This class handles mapping of requested reports
  class ReportEngine
    REPORT_NAMES = {
      'DASHBOARD STATISTICS' => PatientRegistrationService::Reports::Clinic::OverviewReport
    }.freeze

    def reports(start_date, end_date, name)
      name = name.upcase
      REPORT_NAMES[name].new(start_date: start_date, end_date: end_date).data
    end

    def dashboard_stats(date = Date.today)
      REPORT_NAMES['DASHBOARD STATISTICS'].new(date).data
    end
  end
end
