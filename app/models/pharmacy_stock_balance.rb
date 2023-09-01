# frozen_string_literal: true

# This is the model file that will hold the stock card report
class PharmacyStockBalance < ApplicationRecord
  self.table_name = :pharmacy_stock_balances
  self.primary_key = :id

  belongs_to :drug, class_name: 'Drug', foreign_key: :drug_id, optional: true

  # validations
  validates_presence_of :drug_id, :pack_size, :open_balance, :close_balance, :transaction_date
  validates_uniqueness_of :drug_id, scope: %i[pack_size transaction_date]
end
