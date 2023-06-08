# frozen_string_literal: true

module HtsService
  # This is the engine managing all hts reports.
  class ReportEngine
    REPORTS = {
      'HTS SUMMARY' => HtsService::Reports::Moh::HtsSummary,
      'HTS CONFIRMATORY' => HtsService::Reports::Moh::HtsConfirmatory,
      'HTS INITIAL TESTED FOR HIV' => HtsService::Reports::Moh::HtsInitialTestedForHiv,
      'HTS INITIAL TESTED FOR HEPATITIS B' => HtsService::Reports::Moh::HtsInitialTestedForHepb,
      'HTS INITIAL TESTED FOR SYPHILIS' => HtsService::Reports::Moh::HtsInitialTestedForSyphilis,
      'HTS INDEX' => HtsService::Reports::Pepfar::HtsIndex,
      'HTS SELF' => HtsService::Reports::Pepfar::HtsSelf,
      'HTS TST COMMUNITY' => HtsService::Reports::Pepfar::HtsTstCommunity,
      'HTS RECENT COMMUNITY' => HtsService::Reports::Pepfar::HtsRecentCommunity,
      'HTS DASHBOARD STATS' => HtsService::Reports::Stats::HtsDashboard,
      'HTS MONTHLY ACTIVITY LOG' => HtsService::Reports::Clinic::HtsMonthlyActivityLog,
      'HTS HIV TESTING SUMMARY' => HtsService::Reports::Clinic::HtsHivTestingSummary,
      'HTS_LINK' => HtsService::Reports::Clinic::HtsLink,
      'SELF TEST SUMMARY' => HtsService::Reports::Moh::HtsSelfTestSummary,
      'HTS TST FAC' => HtsService::Reports::Pepfar::HtsTstFac1,
      'HTS RECENT FAC' => HtsService::Reports::Pepfar::HtsRecentFac,
      'HTS LEGACY REGULAR' => HtsService::Reports::Clinic::HtsLegacyRegular,
      'HTS LEGACY RETURNING' => HtsService::Reports::Clinic::HtsLegacyReturning,
    }.freeze

    def generate_report(type:, **kwargs)
      call_report_manager(:build_report, type: type, **kwargs)
    end

    def find_report(type:, **kwargs)
      call_report_manager(:data, type: type, **kwargs)
    end

    private

    def call_report_manager(method, type:, **kwargs)
      start_date = kwargs.delete(:start_date)
      end_date = kwargs.delete(:end_date)
      name = kwargs.delete(:name)

      report = REPORTS[name.upcase]
      raise NotFoundError, "#{name} report not found, current reports available #{REPORTS.keys}" if report.blank?

      year = kwargs.delete(:year)
      quarter = kwargs.delete(:quarter)

      if kwargs.empty? && ![start_date, end_date].all? { |date| date&.strip == '' }
        report_manager = report.new(start_date: start_date, end_date: end_date)
      end
      report_manager = report.new(quarter: quarter, year: year) if [quarter, year].all?


      method = report_manager.method(method)
      if kwargs.empty? || [year, quarter].all?
        method.call
      else
        method.call(**kwargs)
      end
    end
  end
end
