# frozen_string_literal: true

module ArtService
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
              COALESCE(psb_opening.close_balance, 0)/pbi.pack_size AS opening_balance,
              COALESCE(psb_closing.close_balance, 0)/pbi.pack_size  AS closing_balance,
              SUM(ABS(po.quantity))/pbi.pack_size AS dispensed_quantity,
              pbi.pack_size
            FROM pharmacy_batch_items AS pbi
            INNER JOIN drug AS d ON d.drug_id = pbi.drug_id
            LEFT JOIN pharmacy_obs AS po ON po.batch_item_id = pbi.id
              AND po.voided = 0
              AND po.pharmacy_encounter_type = 3 -- Pharmacy dispensing
              AND po.transaction_date BETWEEN #{@start_date} AND #{@end_date}
              AND po.dispensation_obs_id IS NOT NULL
            LEFT JOIN (
                SELECT
                    drug_id,
                    MAX(transaction_date) AS transaction_date,
                    pack_size
                FROM pharmacy_stock_balances
                WHERE transaction_date <= #{@end_date}
                GROUP BY drug_id, pack_size
            ) AS psb_max ON pbi.drug_id = psb_max.drug_id AND pbi.pack_size = psb_max.pack_size
            LEFT JOIN (
              SELECT
                  drug_id,
                  MAX(transaction_date) AS transaction_date,
                  pack_size
              FROM pharmacy_stock_balances
              WHERE transaction_date < #{@start_date} -- Opening balance can be anything less than end_date
              GROUP BY drug_id, pack_size
            ) AS psb_min ON pbi.drug_id = psb_min.drug_id AND pbi.pack_size = psb_min.pack_size
            LEFT JOIN pharmacy_stock_balances AS psb_opening ON
                pbi.drug_id = psb_opening.drug_id AND pbi.pack_size = psb_opening.pack_size
                AND psb_opening.transaction_date = psb_min.transaction_date
            LEFT JOIN pharmacy_stock_balances AS psb_closing ON
                pbi.drug_id = psb_closing.drug_id AND pbi.pack_size = psb_closing.pack_size
                AND psb_closing.transaction_date = psb_max.transaction_date
            WHERE pbi.voided = 0
            GROUP BY pbi.drug_id, pbi.pack_size
          SQL
        end
      end
    end
  end
end
