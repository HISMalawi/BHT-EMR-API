# frozen_string_literal: true

FactoryBot.define do
  factory :encounter do
    encounter_datetime { Time.now }
    date_created { Time.now }

    factory :encounter_dispensing do
      association :type, factory: :encounter_type, name: 'Dispensing'
      association :patient
      provider_id { 1 }
      patient_id { 1 }
      location_id { 700 }
    end
  end
end
