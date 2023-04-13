# frozen_string_literal: true

module ARTService
  module Pharmacy
    ##
    # Conviniently access the audit trail (ie transactions)
    module AuditTrail
      class << self
        ##
        # Retrieve audit trail.
        #
        # Parameters:
        #   from: date on which the audit trail should start from.
        #   to: date on which the audit trail should end
        #   drug_id: trail should only be limited to these drugs
        #   batch_number: trail should only be limited to this batch
        #
        # Returns: Array of hashes
        #   {
        #     transaction_date: datetime,
        #     transaction_type: string,
        #     batch_number: string,
        #     drug_name: string,
        #     amount_committed_to_stock: numeric,
        #     amount_dispensed_from_art: numeric,
        #     username: string
        #   }
        #
        # Example:
        #   => ARTService::Pharmacy::Trail.retrieve(from: 3.months.ago)
        #   ... [Transactions starting from 3 months ago]
        def retrieve_drilled_transactions(**kwargs)
          drill_transactions(**kwargs)
            .map { |transaction| serialize_drilled_transaction(transaction) }
        end

        def retrieve_grouped_transactions(**kwargs)
          group_transactions(**kwargs)
          .map { |transaction| serialize_grouped_transaction(transaction) }
        end

        def stock_report
          stock_summary
        end

        private

        def stock_summary
          ActiveRecord::Base.connection.select_all <<~SQL
            SELECT
            pharmacy_batch_items.product_code,
            GROUP_CONCAT(distinct(batch_number)) AS batch_numbers,
            COALESCE(alternative_drug_names.name, drug.name) AS drug_name,
            drug.units,
            SUM(pharmacy_obs.quantity) AS closing_balance,
            SUM(CASE
              WHEN pharmacy_obs.transaction_reason = 'Expired' THEN pharmacy_obs.quantity
              WHEN pharmacy_obs.transaction_reason = 'Damaged' THEN pharmacy_obs.quantity
              WHEN pharmacy_obs.transaction_reason = 'Phased out' THEN pharmacy_obs.quantity
              WHEN pharmacy_obs.transaction_reason = 'Banned' THEN pharmacy_obs.quantity
              WHEN pharmacy_obs.transaction_reason = 'Missing' THEN pharmacy_obs.quantity
              WHEN pharmacy_obs.transaction_reason = 'For trainings' THEN pharmacy_obs.quantity
                ELSE 0
                END) AS losses,
            SUM(CASE
                WHEN pharmacy_obs.transaction_reason = 'Drugs delivered' THEN pharmacy_obs.quantity
                ELSE 0
                END) AS positive_adjustment,
            SUM(CASE
                WHEN pharmacy_obs.transaction_reason = 'Transfer to another facility/relocation' THEN pharmacy_obs.quantity
                ELSE 0
                END) AS negative_adjustment,
            SUM(CASE
                WHEN pharmacy_obs.transaction_reason = 'Drug dispensed' THEN pharmacy_obs.quantity
                ELSE 0
                END) AS quantity_used,
            SUM(CASE
                WHEN pharmacy_obs.transaction_reason = 'Drugs delivered' THEN pharmacy_obs.quantity
                ELSE 0
                END) AS quantity_received
            FROM `pharmacy_obs`
            INNER JOIN `pharmacy_encounter_type` ON `pharmacy_encounter_type`.`retired` = FALSE AND `pharmacy_encounter_type`.`pharmacy_encounter_type_id` = `pharmacy_obs`.`pharmacy_encounter_type`
            INNER JOIN `pharmacy_batch_items` ON `pharmacy_batch_items`.`voided` = FALSE AND `pharmacy_batch_items`.`id` = `pharmacy_obs`.`batch_item_id`
            INNER JOIN `users` ON `users`.`retired` = 0 AND `users`.`user_id` = `pharmacy_obs`.`creator`
            INNER JOIN `drug` ON `drug`.`drug_id` = `pharmacy_batch_items`.`drug_id`
            INNER JOIN `pharmacy_batches` ON `pharmacy_batches`.`voided` = FALSE AND `pharmacy_batches`.`id` = `pharmacy_batch_items`.`pharmacy_batch_id`
            LEFT JOIN alternative_drug_names ON alternative_drug_names.drug_inventory_id = pharmacy_batch_items.drug_id
            LEFT OUTER JOIN `obs` ON `obs`.`voided` = 0 AND `obs`.`obs_id` = `pharmacy_obs`.`dispensation_obs_id`
            WHERE `pharmacy_obs`.`voided` = FALSE
            AND `pharmacy_batch_items`.`voided` = FALSE
            AND `pharmacy_encounter_type`.`retired` = FALSE
            GROUP BY pharmacy_batch_items.product_code, drug.name
            ORDER BY pharmacy_batch_items.product_code ASC
          SQL
        end

        def drill_transactions(from: nil, to: nil, transaction_date: nil, drug_id: nil, batch_number: nil, transaction_reason: nil)
          if transaction_reason == 'Reversing voided drug dispensation'
            transaction_reason_condition = "SUBSTR(pharmacy_obs.transaction_reason, 1, 34) = '#{transaction_reason}'"
          else
            transaction_reason_condition = "pharmacy_obs.transaction_reason = '#{transaction_reason}'"
          end
          transactions(from&.to_date, to&.to_date, transaction_date&.to_date)
            .joins(:type, :item, :user)
            .left_joins(:dispensation)
            .joins('LEFT JOIN alternative_drug_names ON alternative_drug_names.drug_inventory_id = pharmacy_batch_items.drug_id')
            .merge(batch_items(drug_id: drug_id, batch_number: batch_number))
            .merge(transaction_types)
            .where(transaction_reason_condition)
            .order("pharmacy_obs.transaction_date DESC")
            .select <<~SQL
              pharmacy_obs.date_created AS creation_date,
              pharmacy_obs.transaction_date AS transaction_date,
              pharmacy_encounter_type.name AS transaction_type,
              pharmacy_batches.batch_number,
              pharmacy_batch_items.id AS batch_item_id,
              pharmacy_batch_items.drug_id,
              pharmacy_batch_items.pack_size,
              pharmacy_batch_items.product_code,
              COALESCE(alternative_drug_names.name, drug.name) AS drug_name,
              pharmacy_obs.quantity AS amount_committed_to_stock,
              obs.value_numeric AS amount_dispensed_from_art,
              users.username,
              pharmacy_obs.transaction_reason
            SQL
        end

        def group_transactions(from: nil, to: nil, transaction_date: nil, drug_id: nil, batch_number: nil)
          transactions(from&.to_date, to&.to_date, transaction_date&.to_date)
          .joins(:type, :item, :user)
          .left_joins(:dispensation)
          .joins('LEFT JOIN alternative_drug_names ON alternative_drug_names.drug_inventory_id = pharmacy_batch_items.drug_id')
          .merge(batch_items(drug_id: drug_id, batch_number: batch_number))
          .merge(transaction_types)
          .group('pharmacy_obs.transaction_date')
          .group('pharmacy_batch_items.drug_id')
          .group(
            "CASE WHEN SUBSTR(pharmacy_obs.transaction_reason, 1, 34) = 'Reversing voided drug dispensation'
            THEN 'Reversing voided drug dispensation'
            ELSE pharmacy_obs.transaction_reason
            END"
          )
          .order('pharmacy_obs.transaction_date DESC')
          .select <<~SQL
            pharmacy_obs.transaction_date AS transaction_date,
            COALESCE(alternative_drug_names.name, drug.name) AS drug_name,
            pharmacy_batch_items.drug_id,
            pharmacy_batch_items.pack_size,
            SUM(pharmacy_obs.quantity) AS cum_per_day_stock_commited,
            CASE WHEN SUBSTR(pharmacy_obs.transaction_reason, 1, 34) = 'Reversing voided drug dispensation'
            THEN 'Reversing voided drug dispensation'
            ELSE pharmacy_obs.transaction_reason
            END AS transaction_type
          SQL
        end

        def transactions(from, to, transactions_date)
          query = ::Pharmacy.all
          query = query.where('DATE(pharmacy_obs.transaction_date) >= ?', from) if from
          query = query.where('DATE(pharmacy_obs.transaction_date) <= ?', to) if to
          query = query.where('DATE(pharmacy_obs.transaction_date) = ?', transactions_date) if transactions_date
          query
        end

        def batch_items(drug_id: nil, batch_number: nil)
          items = PharmacyBatchItem.joins(:drug, :batch)
          items = items.merge(Drug.where(drug_id: drug_id)) if drug_id
          items = items.merge(PharmacyBatch.where(batch_number: batch_number)) if batch_number

          items
        end

        def dispensations
          amount_dispensed_concept = ConceptName.where(name: 'Amount dispensed').select(:concept_id)
          Observation.where(concept: amount_dispensed_concept) # Might want to filter by ART program
        end

        def transaction_types
          PharmacyEncounterType.all
        end

        def drug_cms(drug_id)
          DrugCms.select(:id, :drug_inventory_id, :name, :short_name, :pack_size).find_by(:drug_inventory_id => drug_id)
        end

        def serialize_drilled_transaction(transaction)
          {
            creation_date: transaction[:creation_date],
            transaction_date: transaction[:transaction_date],
            transaction_type: transaction[:transaction_type],
            batch_number: transaction[:batch_number],
            drug_id: transaction[:drug_id],
            batch_item_id: transaction[:batch_item_id],
            drug_name: transaction[:drug_name],
            amount_committed_to_stock: transaction[:amount_committed_to_stock],
            amount_dispensed_from_art: transaction[:amount_dispensed_from_art],
            username: transaction[:username],
            transaction_reason: transaction[:transaction_reason],
            product_code: transaction[:product_code],
            pack_size: transaction[:pack_size]
          }
        end

        def serialize_grouped_transaction(transaction)
          {
            transaction_date: transaction[:transaction_date],
            transaction_type: transaction[:transaction_type],
            cum_per_day_stock_commited: transaction[:cum_per_day_stock_commited],
            drug_name: transaction[:drug_name],
            drug_id: transaction[:drug_id],
            pack_size: transaction[:pack_size]
          }
        end
      end
    end
  end
end
