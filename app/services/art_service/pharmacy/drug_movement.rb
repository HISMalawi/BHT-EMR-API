# frozen_string_literal: true

module ARTService
  module Pharmacy
    # Aggregates stock movement
    module DrugMovement
      # rubocop:disable Metrics/MethodLength
      # method to fetch all prescribed art's
      def self.fetch(start_date, end_date, drug_id)
        ::Pharmacy
          .joins(
            'LEFT JOIN (pharmacy_batch_items) ON (pharmacy_obs.batch_item_id = pharmacy_batch_items.id)'
          )
          .joins(
            'LEFT JOIN (pharmacy_encounter_type) ON (pharmacy_obs.pharmacy_encounter_type =
               pharmacy_encounter_type.pharmacy_encounter_type_id)'
          )
          .joins(
            'LEFT JOIN (pharmacy_batches) ON (pharmacy_batch_items.pharmacy_batch_id = pharmacy_batches.id)'
          )
          .joins(
            'LEFT JOIN (drug) ON (pharmacy_batch_items.drug_id = drug.drug_id)'
          )
          .where('pharmacy_obs.date_created >= ? AND pharmacy_obs.date_created <= ?', start_date, end_date)
          .where('drug.drug_id = ?', drug_id)
          .select <<~SQL
            pharmacy_obs.quantity AS balance,
            pharmacy_obs.transaction_date AS 'date',
            pharmacy_encounter_type.pharmacy_encounter_type_id AS 'type'
          SQL

        # raise NotFoundError, 'Records not found' if items.empty?
      end
      # rubocop:enable Metrics/MethodLength

      # method to group by date and map based on transaction type
      def self.stock_movement(params)
        results = []
        fetch(params[:start_date], params[:end_date], params[:drug_id]).group_by(&:date).each do |date, items|
          results << {
            transaction_date: date,
            added: compute_sum(items, 2).abs,
            edited: compute_sum(items, 5).abs,
            removed: compute_sum(items, 3).abs
          }
        end
        results
      end

      # computes the sum of balances given an encounter type and a list of item
      def self.compute_sum(items, condition)
        items.select { |x| x[:type] == condition }.map { |y| y[:balance] }.reduce(0) { |a, b| a + b }
      end
    end
  end
end
