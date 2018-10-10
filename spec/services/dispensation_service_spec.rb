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
    # it 'updates order quantity' do
    #   obs = DispensationService.dispense drug_order, 10
    # end

    # it 'creates a new observation' do
    # end

    # order_1 = create :order, patient: patient
    # amount_dispensed_concept = create :amount_dispensed_concept

    # amount_dispensed_concept.destroy
  end
end
