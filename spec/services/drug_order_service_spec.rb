# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DrugOrderService do
  let(:patient) { create :patient }
  let(:service) { DrugOrderService }

  describe :create_drug_orders do
    let(:treatment_encounter) { create :encounter_treatment, patient: patient }
    let(:archetypes) do
      [
        {
          drug_inventory_id: Drug.arv_drugs[0].drug_id,
          start_date: Date.today,
          auto_expire_date: Date.today + 5.days,
          instructions: '1 2 3 4 5 6 7 8 9 10',
          dose: 2,
          prn: 'Whatever',
          units: 'tabs',
          frequency: 'AM, PM',
          equivalent_daily_dose: 6
        }
      ]
    end

    it 'creates a drug_order and an accompanying order for each archetype' do
      created = service.create_drug_orders encounter: treatment_encounter,
                                           drug_orders: archetypes.clone

      expect(created.size).to eq(1)
      expect(created[0].order).not_to be_nil
    end

    it 'fails to create drug order when dose is missing' do
      create_drug_orders = proc do
        partial_archetypes = archetypes.map do |archetype|
          archetype.tap { |hash| hash.delete :dose }
        end

        service.create_drug_orders encounter: treatment_encounter,
                                   drug_orders: partial_archetypes
      end

      expect(&create_drug_orders).to raise_error(InvalidParameterError)
    end
  end
end
