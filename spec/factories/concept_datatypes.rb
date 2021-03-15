# frozen_string_literal: true

FactoryBot.define do
  factory :concept_datatype do
    name { 'foobar' }
    description { 'foobar' }
    creator { 1 }
  end
end
