# frozen_string_literal: true

FactoryBot.define do
  factory :program do
    association :concept
    creator { 1 }
    description { 'foobar' }
    name { 'foobar' }
  end
end
