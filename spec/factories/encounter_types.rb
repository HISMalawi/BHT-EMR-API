# frozen_string_literal: true

require 'securerandom'

FactoryBot.define do
  factory :encounter_type do
    name { SecureRandom.hex }
    description { 'foobar' }
    creator { 1 }
    date_created { Time.now }
  end
end
