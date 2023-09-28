# frozen_string_literal: true

module RadiologyService
  # This is the engine managing all radiology reports.
  class ReportEngine
    REPORT_NAMES = {
      'DASHBOARD STATISTICS' => RadiologyService::Reports::Clinic::ClinicDay,
      'DAILY REPORT' => RadiologyService::Reports::Clinic::DailyReport,
      'REFERRAL REPORT' => RadiologyService::Reports::Clinic::ReferralReport,
      'REVENUE COLLECTED' => RadiologyService::Reports::Clinic::RevenueCollected
    }.freeze

    def reports(start_date, end_date, name)
      name = name.upcase
      REPORT_NAMES[name].new(start_date: start_date, end_date: end_date).data
    end

    def dashboard_stats(date)
      REPORT_NAMES['DASHBOARD STATISTICS'].new(start_date: date, end_date: date).data
    end
  end
end
