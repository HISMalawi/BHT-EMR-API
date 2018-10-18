# frozen_string_literal: true

FactoryBot.define do
  factory :person do
    gender { 'F' }
    birthdate { 18.years.ago }
    creator { 1 }

    factory :person_name do
      association :person
      given_name { 'My name' }
      family_name { 'My family name' }
      middle_name { 'My middle name' }
    end
  end
end
