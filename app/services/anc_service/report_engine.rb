# frozen_string_literal: true

module ANCService
  class ReportEngine
    attr_reader :program

    LOGGER = Rails.logger

    REPORTS = {
      'COHORT' => ANCService::Reports::Cohort,
      'MONTHLY' => ANCService::Reports::Monthly,
      'ANC_COHORT_DISAGGREGATED' => ANCService::Reports::CohortDisaggregated,
      'VISITS' => ANCService::Reports::VisitsReport
    }.freeze

    def generate_report(type:, **kwargs)
      call_report_manager(:build_report, type: type, **kwargs)
    end

    def find_report(type:, **kwargs)
      call_report_manager(:find_report, type: type, **kwargs)
    end

    def cohort_disaggregated(date, start_date)
      start_date = start_date.to_date.beginning_of_month
      end_date = start_date.to_date.end_of_month
      cohort = REPORTS['ANC_COHORT_DISAGGREGATED'].new(type: 'disaggregated',
        name: 'disaggregated', start_date: start_date,
        end_date: end_date, rebuild: false)

      cohort.disaggregated(date, start_date, end_date)
    end

    private

    def call_report_manager(method, type:, **kwargs)
      start_date = kwargs.delete(:start_date)
      end_date = kwargs.delete(:end_date)
      name = kwargs.delete(:name)

      report_manager = REPORTS[type.upcase].new(
        type: type, name: name, start_date: start_date, end_date: end_date
      )
      method = report_manager.method(method)
      if kwargs.empty?
        method.call
      else
        method.call(**kwargs)
      end
    end
  end
end