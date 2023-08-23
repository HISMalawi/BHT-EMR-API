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
              COALESCE(d.name, 'Unkown') AS drug_name,
              COALESCE(psb_opening.open_balance, 0)/pbi.pack_size AS opening_balance,
              COALESCE(psb_closing.close_balance, 0)/pbi.pack_size  AS closing_balance,
              SUM(ABS(po.quantity))/pbi.pack_size AS dispensed_quantity,
              pbi.pack_size
            FROM pharmacy_batch_items AS pbi
            INNER JOIN drug AS d ON d.drug_id = pbi.drug_id
            LEFT JOIN pharmacy_obs AS po ON po.batch_item_id = pbi.id
              AND po.voided = 0
              AND po.pharmacy_encounter_type = 3 -- Pharmacy dispensing
              AND po.transaction_date BETWEEN #{@start_date} AND #{@end_date}
            LEFT JOIN (
                SELECT
                    drug_id,
                    MIN(transaction_date) AS min_transaction_date,
                    MAX(transaction_date) AS max_transaction_date,
                    pack_size
                FROM pharmacy_stock_balances
                WHERE transaction_date < #{@end_date} -- Opening balance can be anything less than end_date
                GROUP BY drug_id, pack_size
            ) AS psb_min_max ON pbi.drug_id = psb_min_max.drug_id AND pbi.pack_size = psb_min_max.pack_size
            LEFT JOIN pharmacy_stock_balances AS psb_opening ON
                pbi.drug_id = psb_opening.drug_id AND pbi.pack_size = psb_opening.pack_size
                AND psb_opening.transaction_date = psb_min_max.min_transaction_date
            LEFT JOIN pharmacy_stock_balances AS psb_closing ON
                pbi.drug_id = psb_closing.drug_id AND pbi.pack_size = psb_closing.pack_size
                AND psb_closing.transaction_date = psb_min_max.max_transaction_date
            WHERE pbi.voided = 0
            GROUP BY pbi.drug_id, pbi.pack_size
          SQL
        end

        # def stock_card_report
        #   ActiveRecord::Base.connection.select_all <<~SQL
        #     SELECT
        #         pbi.drug_id AS drug_id,
        #         COALESCE(dc.short_name, dc.name, d.name, 'Unkown') AS drug_name,
        #         first_stock.open_balance AS opening_balance,
        #         current_stock.close_balance AS closing_balance,
        #         SUM(ABS(po.quantity))/SUM(pbi.pack_size) AS dispensed_quantity,
        #         pbi.pack_size
        #     FROM pharmacy_stock_balances AS psb
        #     INNER JOIN pharmacy_batch_items AS pbi ON pbi.drug_id = psb.drug_id AND pbi.pack_size = psb.pack_size
        #     INNER JOIN drug AS d ON d.drug_id = pbi.drug_id
        #     INNER JOIN (
        #       SELECT drug_id, pack_size, MAX(transaction_date) AS transaction_date
        #       FROM pharmacy_stock_balances
        #       WHERE transaction_date BETWEEN #{@start_date} AND #{@end_date}
        #       GROUP BY drug_id, pack_size
        #     ) AS current_stock ON current_stock.drug_id = psb.drug_id AND current_stock.pack_size = psb.pack_size AND current_stock.transaction_date = psb.transaction_date
        #     INNER JOIN (
        #       SELECT drug_id, pack_size, MIN(transaction_date) AS transaction_date
        #       FROM pharmacy_stock_balances
        #       WHERE transaction_date BETWEEN #{@start_date} AND #{@end_date}
        #     ) AS first_stock ON first_stock.drug_id = psb.drug_id AND first_stock.pack_size = psb.pack_size AND first_stock.transaction_date = psb.transaction_date
        #     LEFT JOIN drug_cms AS dc ON dc.drug_inventory_id = d.drug_id
        #     LEFT JOIN pharmacy_obs AS po ON po.batch_item_id = pbi.id
        #         AND po.voided = 0
        #         AND po.pharmacy_encounter_type = 3 -- Pharmacy dispensing
        #         AND po.transaction_date BETWEEN #{@start_date} AND #{@end_date}
        #     WHERE psb.transaction_date BETWEEN #{@start_date} AND #{@end_date}
        #     GROUP BY pbi.drug_id
        #   SQL
        # end
      end
    end
  end
end
