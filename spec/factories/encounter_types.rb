# frozen_string_literal: true

FactoryBot.define do
  factory :encounter_type do
    creator { 1 }
    date_created { Time.now }
  end
end
