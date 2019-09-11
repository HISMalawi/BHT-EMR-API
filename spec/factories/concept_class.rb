# frozen_string_literal: true

FactoryBot.define do
  factory :concept_class do
    name { 'foobar' }
    description { 'foobar' }
    creator { 1 }
  end
end
