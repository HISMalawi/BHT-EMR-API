# frozen_string_literal: true

FactoryBot.define do
  factory :pharmacy_batch_item do
    pharmacy_batch_id { 1 }
    drug_id { 1 }
    delivered_quantity { 1.5 }
    current_quantity { 1.5 }
    delivery_date { '2019-05-08' }
    expiry_date { '2019-05-08' }
  end
end
