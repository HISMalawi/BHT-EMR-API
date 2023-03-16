# frozen_string_literal: true

# This migration comes from pharmacy
class AddStockVerificationToPharmacy < ActiveRecord::Migration[5.2]
  def change
    add_reference :pharmacy_obs, :stock_verification, foreign_key: { to_table: :pharmacy_stock_verifications }, index: true, default: nil
  end
end
