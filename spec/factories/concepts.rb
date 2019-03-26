# frozen_string_literal: true

FactoryBot.define do
  factory :concept do
    date_created { Time.now }

    factory :concept_amount_dispensed do
      after(:create) do
        create_list :concept_name, 1, name: 'AMOUNT DISPENSED'
      end
    end
  end
end
