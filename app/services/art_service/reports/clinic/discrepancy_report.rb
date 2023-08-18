# frozen_string_literal: true

module ARTService
  module Reports
    module Clinic
      # Generates a discrepancy report for a clinic
      class DiscrepancyReport
        def initialize(start_date:, end_date:, **_kwargs)
          @start_date = ActiveRecord::Base.connection.quote(start_date)
          @end_date = ActiveRecord::Base.connection.quote(end_date)
        end

        def find_report
            # TODO: Implement this
        end

        private

        def discrepancy_report
            ActiveRecord::Base.connection.select_all <<~SQL
                SELECT *
                FROM pharmacy_stock_verifications psv
                INNER JOIN pharmacy_obs po ON po.stock_verification_id = psv.stock_verification_id AND po.voided = 0
                
            SQL
        end
      end
    end
  end
end
