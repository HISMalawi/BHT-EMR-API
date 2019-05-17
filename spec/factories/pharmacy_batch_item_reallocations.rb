FactoryBot.define do
  factory :pharmacy_batch_item_reallocation do
    reallocation_code { "" }
    batch_item_id { "" }
    quantity { "" }
    location_id { 1 }
  end
end
