# frozen_string_literal: true

FactoryBot.define do
  factory :drug do
    association :concept
    name { 'Foobar' }
    date_created { Time.now }
  end
end
