# frozen_string_literal: true

module ARTService
  module Reports
    module Clinic
      # Generates a stock card report for a clinic
      class StockCardReport
        def initialize(start_date:, end_date:, **_kwargs)
          @start_date = ActiveRecord::Base.connection.quote(start_date)
          @end_date = ActiveRecord::Base.connection.quote(end_date)
        end

        def find_report
          # TODO: Implement this
        end

        private

        def stock_card_report
          ActiveRecord::Base.connection.select_all <<~SQL
          SQL
        end
      end
    end
  end
end
