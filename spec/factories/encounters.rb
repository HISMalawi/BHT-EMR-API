# frozen_string_literal: true

FactoryBot.define do
  factory :encounter do
    association :patient
    association :program

    encounter_datetime { Time.now }
    date_created { Time.now }
    creator { 1 }
    provider_id { 1 }
    location_id { 700 }
    program_id { 1 }

    factory :encounter_dispensing do
      type { EncounterType.find_by_name 'Dispensing' }
      # patient_id { 1 }
      # location_id { 700 }
    end

    factory :encounter_appointment do
      type { EncounterType.find_by_name 'Appointment' }
    end

    factory :encounter_treatment do
      type { EncounterType.find_by_name 'TREATMENT' }
    end

    factory :encounter_vitals do
      type { EncounterType.find_by_name 'VITALS' }
    end
  end
end
