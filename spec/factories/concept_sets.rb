# frozen_string_literal: true

FactoryBot.define do
  factory :concept_set do
    association :set, factory: :concept
    association :concept

    creator { User.first.user_id }
    date_created { Time.now }
    uuid { SecureRandom.uuid }
  end
end
