# frozen_string_literal: true

module HtsService
  # This is the engine managing all hts reports.
  class ReportEngine
    REPORT_NAMES = {
      'HTS INDEX' => HtsService::Reports::Pepfar::HtsIndex,
      'HTS SELF' => HtsService::Reports::Pepfar::HtsSelf,
      'HTS TST COMMUNITY' => HtsService::Reports::Pepfar::HtsTstCommunity,
      'HTS RECENT COMMUNITY' => HtsService::Reports::Pepfar::HtsRecentCommunity
    }.freeze

    def reports(start_date, end_date, name)
      name = name.upcase
      REPORT_NAMES[name].new(start_date: start_date, end_date: end_date).fetch_report
    end
  end
end