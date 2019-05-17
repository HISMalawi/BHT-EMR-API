# frozen_string_literal: true

FactoryBot.define do
  factory :drug do
    association :concept

    name { 'Foobar' }
    date_created { Time.now }

    factory :lacoca_drug do
      concept { create(:concept, concept_name: create(:concept_name, name: 'Coca')) }
    end
  end
end
