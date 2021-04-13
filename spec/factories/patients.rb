# frozen_string_literal: true

FactoryBot.define do
  factory :patient do
    patient_id { create(:person).person_id }
    creator { 1 }
  end
end
