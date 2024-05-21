# frozen_string_literal: true

module ArtService
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
          discrepancy_report
        end

        private

        def discrepancy_report
          ActiveRecord::Base.connection.select_all <<~SQL
            SELECT
                pbi.drug_id,
                d.name,
                d.short_name,
                psv.verification_date,
                psv.reason as verification_reason,
                po_expected.quantity expected_quantity,
                po.quantity difference,
                po_expected.quantity + po.quantity as current_quantity,
                po.transaction_reason as variance_reason
            FROM pharmacy_stock_verifications psv
            INNER JOIN pharmacy_obs po ON po.stock_verification_id = psv.id AND po.voided = 0 AND po.obs_group_id IS NULL
            INNER JOIN pharmacy_batch_items pbi ON pbi.id = po.batch_item_id AND pbi.voided = 0
            INNER JOIN drug_cms d ON d.drug_inventory_id = pbi.drug_id AND d.voided = 0
            LEFT JOIN pharmacy_obs po_expected ON po_expected.obs_group_id = po.pharmacy_module_id AND po_expected.voided = 0
            WHERE psv.verification_date BETWEEN #{@start_date} AND #{@end_date}
            GROUP BY psv.id
          SQL
        end
      end
    end
  end
end
