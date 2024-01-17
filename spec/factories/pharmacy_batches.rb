FactoryBot.define do
  factory :pharmacy_batch do
    batch_number { "MyString" }
    drug_id { 1 }
    initial_quantity { 1.5 }
    current_quantity { 1.5 }
    delivery_date { "2019-05-03" }
    expiry_date { "2019-05-03" }
  end
end
