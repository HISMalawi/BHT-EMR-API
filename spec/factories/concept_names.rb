# frozen_string_literal: true

FactoryBot.define do
  factory :concept_name do
    date_created { Time.now }
    creator { 1 }
  end
end
