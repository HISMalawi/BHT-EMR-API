# frozen_string_literal: true

require 'ostruct'

module LaboratoryService
  class ReportEngine
    attr_reader :program

    LOGGER = Rails.logger

    REPORTS = {
      'SAMPLES_DRAWN' => LaboratoryService::Reports::Clinic::SamplesDrawn,
      'PROCESSED_RESULTS' => LaboratoryService::Reports::Clinic::ProcessedResults
    }.freeze

    def find_report(type: nil, **kwargs)
      report_class = REPORTS[type.upcase]
      raise NotFoundError, "Report #{type} does not exist in Laboratory service" unless report_class

      report_class.new(**kwargs).read
    end

    def samples_drawn(start_date, end_date)
      REPORTS['SAMPLES_DRAWN'].new(start_date:, end_date:).samples_drawn
    end

    def test_results(start_date, end_date, **kwargs)
      REPORTS['SAMPLES_DRAWN'].new(start_date:, end_date:, **kwargs).test_results
    end

    def orders_made(start_date, end_date, status)
      REPORTS['SAMPLES_DRAWN'].new(start_date:, end_date:).orders_made(status)
    end
  end
end
