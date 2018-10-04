# frozen_string_literal: true

FactoryBot.define do
  factory :person do
    gender { 'F' }
    birthdate { 18.years.ago }

    factory :person_name do
      association :person
      given_name { 'My name' }
      family_name { 'My family name' }
      middle_name { 'My middle name' }
    end
  end

  factory :dispensation, class: Observation do
    association :encounter, factory: :encounter_dispensing
    # factory :encounter do
    #   factory :concept do
    #     factory :concept_name do
    #       name { 'AMOUNT DISPENSED' }
    #     end
    #   end
    # end
  end
end
