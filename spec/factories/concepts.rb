# frozen_string_literal: true

FactoryBot.define do
  factory :concept do
    date_created { Time.now }
    association :concept_datatype
    association :concept_class
    creator { 1 }

    factory :concept_with_name do
      after :create do |concept|
        create_list :concept_name, 1, concept: concept
      end
    end

    factory :concept_amount_dispensed do
      after :create do |concept|
        create_list :concept_name, 1, concept: concept, name: 'AMOUNT DISPENSED'
      end
    end
  end
end
