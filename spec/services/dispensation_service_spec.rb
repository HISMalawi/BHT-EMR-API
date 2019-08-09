# frozen_string_literal: true

require 'rails_helper'
require 'set'

RSpec.describe DispensationService do
  let(:patient) { create :patient }

  describe :dispensations do
    it 'retrieves all dispensations for a given patient' do
      created = (1...10).collect do |i|
        create :dispensation, person: patient.person,
                              obs_datetime: Time.now - i.days
      end

      retrieved = DispensationService.dispensations patient.patient_id

      expect(Set.new(retrieved)).to eq(Set.new(created))
    end

    it 'retrieves dispensations for a given patient and date' do
      retro_date = 5.days.ago.to_date
      created = (1...10).collect do
        create :dispensation, person: patient.person, obs_datetime: retro_date
      end

      retrieved = DispensationService.dispensations patient.patient_id, retro_date

      expect(Set.new(retrieved)).to eq(Set.new(created))
    end
  end

  describe :dispense_drug do
    it 'updates order quantity' do
      program = create :program
      encounter = create :encounter_treatment, patient: patient
      drug = Drug.arv_drugs[0]
      order = create :order, encounter: encounter, patient: patient,
                             concept: drug.concept, start_date: Date.today,
                             auto_expire_date: 10.days.after
      drug_order = create :drug_order, order: order, drug: drug

      obs = DispensationService.dispense_drug(program, drug_order, 10)

      expect(obs.concept_id).to eq(concept('AMOUNT DISPENSED').concept_id)
      expect(obs.order).to eq(order)
      expect(obs.order.drug_order.quantity).to eq(10)
    end
  end
end
