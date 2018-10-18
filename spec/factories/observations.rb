# frozen_literal_string: true

FactoryBot.define do
  factory :observation do
    association :encounter
    creator { 1 }

    factory :obs_appointment do
      concept do
        Concept.joins(:concept_names)\
               .where('concept_name.name = ?', 'Appointment Date')\
               .first
      end
      obs_datetime { Time.now }
      value_datetime { Time.now }
    end
  end
end
