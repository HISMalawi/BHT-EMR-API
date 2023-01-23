FactoryBot.define do
  factory :patient_identifier do
    association :patient
    location_id { Location.current_health_center.id }
  end
end
