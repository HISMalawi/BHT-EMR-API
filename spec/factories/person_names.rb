# frozen_string_literal: true

FactoryBot.define do
  factory :person_name do
    association :person

    given_name { 'first' }
    family_name { 'last' }
    middle_name { 'middle' }
  end
end
