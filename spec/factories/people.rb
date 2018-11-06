# frozen_string_literal: true

FactoryBot.define do
  factory :person do
    gender { 'F' }
    birthdate { 18.years.ago }
    creator { 1 }
  end
end
