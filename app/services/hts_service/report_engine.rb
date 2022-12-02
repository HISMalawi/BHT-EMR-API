# frozen_string_literal: true

module HtsService
  # This is the engine managing all hts reports.
  class ReportEngine
    REPORTS = {
      'HTS INDEX' => HtsService::Reports::Pepfar::HtsIndex,
      'HTS SELF' => HtsService::Reports::Pepfar::HtsSelf,
      'HTS TST COMMUNITY' => HtsService::Reports::Pepfar::HtsTstCommunity,
      'HTS RECENT COMMUNITY' => HtsService::Reports::Pepfar::HtsRecentCommunity,
      'HTS DASHBOARD STATS' => HtsService::Reports::Stats::HtsDashboard
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

      report_manager = report.new(start_date: start_date, end_date: end_date)
      method = report_manager.method(method)
      if kwargs.empty?
        method.call
      else
        method.call(**kwargs)
      end
    end
  end
end
