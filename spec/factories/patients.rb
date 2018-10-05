# frozen_string_literal: true

FactoryBot.define do
  factory :patient do
    association :person
  end
end
