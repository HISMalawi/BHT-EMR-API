#frozen_string_literal: true

module ImmunizationService
  #This is the engine managing all immunization reports.
  class ReportEngine
    REPORTS = {
      'IMMUNIZATION FOLLOW UP' => ImmunizationService::Reports::General::ImmunizationFollowUp,
    }.freeze

    def generate_report(type:, **kwargs)
      call_report_manager(:build_report, type:, **kwargs)
    end

    def find_report(type:, **kwargs)
      call_report_manager(:data, type:, **kwargs)
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
        report_manager = report.new(start_date:, end_date:)
      end
      report_manager = report.new(quarter:, year:) if [quarter, year].all?

      method = report_manager.method(method)
      if kwargs.empty? || [year, quarter].all?
        method.call
      else
        method.call(**kwargs)
      end
    end
  end
end
