# frozen_string_literal: true

FactoryBot.define do
  factory :dispensation, class: Observation do
    association :encounter, factory: :encounter_dispensing
    creator { 1 }
    # factory :encounter do
    #   factory :concept do
    #     factory :concept_name do
    #       name { 'AMOUNT DISPENSED' }
    #     end
    #   end
    # end
  end
end
