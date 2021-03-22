# frozen_string_literal: true

FactoryBot.define do
  factory :drug do
    association :concept

    name { 'Foobar' }
    date_created { Time.now }

    factory :lacoca_drug do
      concept do
        concept = create(:concept)
        create(:concept_name, concept: concept)

        concept
      end
    end
  end
end
