# frozen_string_literal: true

FactoryBot.define do
  factory :drug_order do
    association :drug
    association :order

    dose { 10 }
    equivalent_daily_dose { 2 }
    units { 'pills' }
    frequency { 'foobar' }
    prn { 0 }
    complex { 0 }
  end
end
