# frozen_literal_string: true

FactoryBot.define do
  factory :observation do
    association :encounter
    creator { 1 }
  end
end
