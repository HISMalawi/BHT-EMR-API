# frozen_string_literal: true

# This migration comes from pharmacy
class AddStockVerificationToPharmacy < ActiveRecord::Migration[5.2]
  def up
    # check if the foreign key already exists
    unless foreign_key_exists?(:pharmacy_obs, :pharmacy_stock_verifications)
      add_reference :pharmacy_obs, :stock_verification, foreign_key: { to_table: :pharmacy_stock_verifications }, index: true, default: nil
    end
  end
  
  def down
    remove_reference :pharmacy_obs, :stock_verification
  end
end
