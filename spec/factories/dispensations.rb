# frozen_string_literal: true

FactoryBot.define do
  factory :dispensation, class: Observation do
    association :encounter, factory: :encounter_dispensing
    concept_id do
      concept_type = ConceptName.find_by_name 'AMOUNT DISPENSED'
      concept_type.concept_id
    end
    association :person
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
