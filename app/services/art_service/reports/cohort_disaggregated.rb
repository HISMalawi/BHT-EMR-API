# frozen_string_literal: true

module ARTService
  module Reports
    class CohortDisaggregated
      def initialize(name:, type:, start_date:, end_date:)
        @name = name
        @type = type
        @start_date = start_date
        @end_date = end_date
      end

      def find_report
        build_report
      end

      def build_report
        builder = CohortDisaggregatedBuilder.new
        builder.build(nil, @start_date, @end_date)
      end
    end
  end
end
