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
        def retrieve(**kwargs)
          fetch_transactions(**kwargs)
            .map { |transaction| serialize_transaction(transaction) }
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

        def fetch_transactions(from: nil, to: nil, drug_id: nil, batch_number: nil)
          transactions(from&.to_date, to&.to_date)
            .joins(:type, :item, :user)
            .left_joins(:dispensation)
            .joins('LEFT JOIN alternative_drug_names ON alternative_drug_names.drug_inventory_id = pharmacy_batch_items.drug_id')
            .merge(batch_items(drug_id: drug_id, batch_number: batch_number))
            .merge(transaction_types)
            .order("pharmacy_obs.transaction_date DESC")
            .select <<~SQL
              pharmacy_obs.date_created AS creation_date,
              pharmacy_obs.transaction_date AS transaction_date,
              pharmacy_encounter_type.name AS transaction_type,
              pharmacy_batches.batch_number,
              pharmacy_batch_items.id AS batch_item_id,
              pharmacy_batch_items.drug_id,
              pharmacy_batch_items.product_code,
              COALESCE(alternative_drug_names.name, drug.name) AS drug_name,
              pharmacy_obs.quantity AS amount_committed_to_stock,
              obs.value_numeric AS amount_dispensed_from_art,
              users.username,
              pharmacy_obs.transaction_reason
            SQL
        end

        def transactions(from, to)
          query = ::Pharmacy.all
          query = query.where('pharmacy_obs.date_created >= ?', from) if from
          query = query.where('pharmacy_obs.date_created < ?', to) if to
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

        def serialize_transaction(transaction)
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
            product_code: transaction[:product_code]
          }
        end
      end
    end
  end
end
