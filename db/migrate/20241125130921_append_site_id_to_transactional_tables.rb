# frozen_string_literal: true

class AppendSiteIdToTransactionalTables < ActiveRecord::Migration[7.0]
  TRANSACTIONAL_TABLES = %w[users person_name drug_ingredients drug_order encounter orders obs patient_program
                            patient_state person_address pharmacies pharmacy_batch_items pharmacy_batches pharmacy_stock_balances pharmacy_stock_verifications relationship].freeze

  def up
    TRANSACTIONAL_TABLES.each do
      add_column _1.to_sym, :site_id, :integer, default: 0 unless column_exists?(_1, :site_id)
    end
  end
end
