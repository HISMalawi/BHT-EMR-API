# frozen_string_literal: true

module RadiologyService
  module Reports
    module Clinic
      # This class is used to generate the revenue collected report.
      class RevenueCollected
        def initialize(start_date:, end_date:)
          @start_date = start_date.to_date.strftime('%Y-%m-%d 00:00:00')
          @end_date = end_date.to_date.strftime('%Y-%m-%d 23:59:59')
        end

        def data
          report
        end

        private

        def report
          ActiveRecord::Base.connection.select_all <<~SQL
            SELECT SUM(o.value_numeric) as total_revenue
            FROM obs o
            WHERE o.voided = 0
            AND o.concept_id IN (SELECT concept_id FROM concept_name WHERE name IN ('PAYMENT AMOUNT','INVOICE AMOUNT') AND voided = 0)
            AND o.obs_datetime BETWEEN '#{@start_date}' AND '#{@end_date}'
            GROUP BY o.concept_id
          SQL
        end
      end
    end
  end
end
