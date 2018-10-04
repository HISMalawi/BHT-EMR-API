# frozen_string_literal: true

RSpec.describe DispensationService, type: :feature do
  # Dispensation involves all 3 models below
  let(:patient) { create :patient }

  describe :dispensations do
    it 'retrieves all dispensations for a given patient' do
      created = (1..10).collect { |i| create :dispensation, obs_datetime: i.days.ago }

      retrieved = DispensationService.find_dispensations patient.patient_id

      expect(created.map(&:obs_datetime).sort).to eq(retrieved.map(&:obs_datetime).sort)
      created.each(&:delete)
    end

    it 'retrieves dispensations for a given patient and date' do
      retro_date = 5.days.ago.to_date

      created = (1..10).collect { create :dispensation, obs_datetime: retro_date }

      retrieved = DispensationService.find_dispensations patient.patient_id, retro_date

      expect(created.map(&:obs_id).sort).to eq(retrieved.map(&:obs_id).sort)
      created.each(&:delete)
    end
  end

  describe :dispense do
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
