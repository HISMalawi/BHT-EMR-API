# frozen_string_literal: true

require 'securerandom'

FactoryBot.define do
  factory :order_type do
    name { SecureRandom.hex }
    creator { 1 }
    uuid { SecureRandom.uuid }
  end
end
