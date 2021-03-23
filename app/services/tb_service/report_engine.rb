# frozen_string_literal: true

require 'set'
include TimeUtils


module TBService
  class ReportEngine
    attr_reader :program
    include ModelUtils

    LOGGER = Rails.logger

    REPORTS = {
      'TBHIV' => TBService::Reports::Tbhiv,
      'QUARTERLY' => TBService::Reports::Quarterly,
      'CASEFINDING' => TBService::Reports::CaseFinding
    }.freeze

    def find_report(type:, name:, start_date:, end_date:)
      report = REPORTS[type.upcase]
      raise InvalidParameterError, "Report type (#{type}) not known" unless report

      indicator = report.method(name.strip.to_sym)
      raise InvalidParameterError, "Report indicator (#{name}) not known" unless indicator

      start_date = start_date.to_time
      _, end_date = TimeUtils.day_bounds(end_date)

      { name => indicator.call(start_date, end_date) }
    end

    def dashboard_stats(date)
      TBService::Reports::Overview.statistics(date)
    end
  end
end
