# frozen_string_literal: true

# Pharmacy stock verification model
class PharmacyStockVerification < VoidableRecord
  has_many :pharmac_obs, class_name: 'Pharmacy', foreign_key: :stock_verification_id

  validates :verification_date, presence: true
  validates :reason, presence: true
end
