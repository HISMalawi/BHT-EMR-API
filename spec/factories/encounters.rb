# frozen_string_literal: true

FactoryBot.define do
  factory :encounter do
    association :patient
    encounter_datetime { Time.now }
    date_created { Time.now }
    creator { 1 }
    provider_id { 1 }
    location_id { 700 }

    factory :encounter_dispensing do
      type { EncounterType.find_by_name('Dispensing') }
      # patient_id { 1 }
      # location_id { 700 }
    end

    factory :encounter_appointment do
      type { EncounterType.find_by_name('Appointment') }
    end
  end
end
