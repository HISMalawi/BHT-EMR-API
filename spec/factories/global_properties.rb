# frozen_string_literal: true

require 'securerandom'

FactoryBot.define do
  factory :global_property do
    uuid { SecureRandom.uuid }
  end
end
