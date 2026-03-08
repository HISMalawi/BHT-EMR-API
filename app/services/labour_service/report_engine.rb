# frozen_string_literal: true

module LabourService
  class ReportEngine
    include ModelUtils

    attr_reader :program
    LOGGER = Rails.logger

    def initialize(program: nil)
      @program = program
    end

    def dashboard_stats(_date = nil, **)
      stats = LabourService::DashboardStatsQueries.new.dashboard_stats_hash
      LOGGER.info "[Labour ReportEngine] dashboard_stats stats=#{stats}"
      stats
    end

    def generate_report(type:, **kwargs)
      call_report_manager(:build_report, type: type, **kwargs)
    end

    def find_report(type:, **kwargs)
      call_report_manager(:find_report, type: type, **kwargs)
    end

    private

    def call_report_manager(method, type:, **kwargs)
      report_class = REPORTS[type.to_s.upcase]
      return nil unless report_class

      start_date = kwargs.delete(:start_date)
      end_date = kwargs.delete(:end_date)
      name = kwargs.delete(:name)

      report_manager = report_class.new(
        type: type, name: name, start_date: start_date, end_date: end_date
      )
      report_manager.public_send(method, **kwargs)
    end

    REPORTS = {}.freeze
  end
end
