# frozen_string_literal: true

FactoryBot.define do
  factory :order do
    association :concept
    association :order_type
    provider { User.find(1).person }
    creator { 1 }
  end
end
