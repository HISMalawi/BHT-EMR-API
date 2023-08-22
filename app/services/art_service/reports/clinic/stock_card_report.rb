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
          stock_card_report
        end

        private

        def stock_card_report
          ActiveRecord::Base.connection.select_all <<~SQL
            SELECT
                pbi.drug_id AS drug_id,
                COALESCE(dc.short_name, dc.name, d.name, 'Unkown') AS drug_name,
                SUM(pbi.current_quantity)/SUM(pbi.pack_size) AS current_quantity,
                SUM(pbi.delivered_quantity)/SUM(pbi.pack_size) AS delivered_quantity,
                SUM(ABS(po.quantity))/SUM(pbi.pack_size) AS dispensed_quantity,
                pbi.pack_size
            FROM pharmacy_batch_items AS pbi
            INNER JOIN drug AS d ON d.drug_id = pbi.drug_id
            LEFT JOIN drug_cms AS dc ON dc.drug_inventory_id = d.drug_id
            LEFT JOIN pharmacy_obs AS po ON po.batch_item_id = pbi.id
                AND po.voided = 0
                AND po.pharmacy_encounter_type = 3 -- Pharmacy dispensing
                AND po.transaction_date BETWEEN #{@start_date} AND #{@end_date}
            WHERE pbi.delivery_date <= #{@end_date}
            GROUP BY pbi.drug_id
          SQL
        end
      end
    end
  end
end
