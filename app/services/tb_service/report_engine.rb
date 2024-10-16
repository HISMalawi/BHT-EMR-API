# frozen_string_literal: true

module TbService
  class ReportEngine
    attr_reader :program

    include TimeUtils
    include ModelUtils

    LOGGER = Rails.logger

    REPORTS = {
      'TBHIV' => TbService::Reports::Tbhiv,
      'QUARTERLY' => TbService::Reports::Quarterly,
      'CASEFINDING' => TbService::Reports::CaseFinding,
      'PRESUMPTIVES' => TbService::Reports::Presumptives,
      'CONTACTS' => TbService::Reports::Contacts,
      'HIGHRISKPATIENTS' => TbService::Reports::HighRiskPatients,
      'IPTOUTCOMES' => TbService::Reports::IptOutcomes,
      'COMMUNITY' => TbService::Reports::Community,
      'MDR_CASEFINDING' => TbService::Reports::MdrCaseFinding,
      'MDR_OUTCOMES' => TbService::Reports::MdrOutcomes,
      'MDR_INTERIM_OUTCOMES' => TbService::Reports::MdrInterimOutcomes
    }.freeze

    def find_report(type:, name:, start_date:, end_date:)
      report = REPORTS[type.upcase]
      raise InvalidParameterError, "Report type (#{type}) not known" unless report

      #  for TB quarterly reports, the report is calculated for the previous year
      if type.upcase == 'QUARTERLY'
        start_date = start_date.to_date - 1.year
        end_date = end_date.to_date - 1.year
      end

      indicator = report.method(name.strip.to_sym)
      raise InvalidParameterError, "Report indicator (#{name}) not known" unless indicator

      start_date = start_date.to_time
      _, end_date = TimeUtils.day_bounds(end_date)

      report.format_report(indicator: name, report_data: indicator.call(start_date, end_date), start_date:, end_date:)
    end

    def dashboard_stats(date)
      TbService::Reports::Overview.new.statistics(date)
    end
  end
end
