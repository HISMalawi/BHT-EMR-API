# frozen_string_literal: true

module ARTService
  class ReportEngine
    attr_reader :program

    LOGGER = Rails.logger

    REPORTS = {
      'COHORT' => ARTService::Reports::Cohort
    }.freeze

    def generate_report(type:, **kwargs)
      LOGGER.debug("Generating report(#{kwargs})")
      type = ReportType.find(type)
      report_builder = REPORTS[type.name.upcase].new(type: type, **kwargs)
      report_builder.build_report
    end
  end
end
