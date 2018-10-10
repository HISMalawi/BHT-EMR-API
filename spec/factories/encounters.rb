# frozen_string_literal: true

FactoryBot.define do
  factory :encounter do
    encounter_datetime { Time.now }
    date_created { Time.now }
    creator { 1 }
    association :patient

    factory :encounter_dispensing do
      type { EncounterType.find_by_name('Dispensing') }
      provider_id { 1 }
      # patient_id { 1 }
      # location_id { 700 }
    end
  end
end
