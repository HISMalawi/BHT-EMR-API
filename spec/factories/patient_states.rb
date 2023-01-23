# frozen_string_literal: true

FactoryBot.define do
  factory :patient_state do
    association :patient_program
    state { 7 }
    start_date { Date.today - 6.months }
    creator { 1 }
  end
end
