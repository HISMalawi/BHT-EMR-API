# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TbService::AppointmentEngine do
  subject { TbService::AppointmentEngine }
  let(:patient) { create :patient }
  let(:program) { Program.find_by_name('TB Program') }
  let(:epoch) { Date.today }

  describe :next_appointment do
    it 'does not suggest appointments on clinic days' do
      epoch = Date.strptime '2018-10-23' # Was a tuesday...

      treatment_encounter = create :encounter_treatment, patient: patient,
                                                         encounter_datetime: epoch,
                                                         program: program
      drug = Drug.tb_drugs[0]

      order = create :order, auto_expire_date: epoch,
                             start_date: epoch,
                             patient: patient,
                             concept: drug.concept,
                             encounter: treatment_encounter

      create :drug_order, order: order, drug: drug

      # Expecting a 4 day backward shift as the conventional 2 lands on
      # a sunday which is a default non-clinic day. Saturday too is skipped
      # as it is another non-clinic day.
      expected_date = (epoch - 4.days).to_date

      engine = subject.new program: program, patient: patient, retro_date: epoch
      date = engine.next_appointment_date[:appointment_date]
      expect(date).to eq(expected_date)
    end

    it 'adjusts shortest expiry date back by 2 days' do
      epoch = Date.strptime '2018-10-26' # Was a friday...

      treatment_encounter = create :encounter_treatment, patient: patient,
                                                         encounter_datetime: epoch,
                                                         program: program
      drug = Drug.tb_drugs[0]

      order = create :order, auto_expire_date: epoch,
                             start_date: epoch,
                             patient: patient,
                             concept: drug.concept,
                             encounter: treatment_encounter

      create :drug_order, order: order, drug: drug

      expected_date = (epoch - 2.days).to_date

      engine = subject.new program: program, patient: patient, retro_date: epoch
      date = engine.next_appointment_date[:appointment_date]
      expect(date).to eq(expected_date)
    end

    it 'selects shortest expiry date among available drug orders' do
      epoch = Date.strptime '2018-10-24' # Was a wednesday...

      treatment_encounter = create :encounter_treatment, patient: patient,
                                                         encounter_datetime: epoch,
                                                         program: program
      tb_drugs = Drug.tb_drugs

      (0...5).collect do |i|
        drug = tb_drugs[i]
        order = create :order, auto_expire_date: epoch + i.days,
                               start_date: epoch,
                               patient: patient,
                               concept: drug.concept,
                               encounter: treatment_encounter

        create :drug_order, order: order, drug: drug
      end

      # Expecting a 2 day backward shift from our epoch must be our shortest
      # expiry date
      expected_date = (epoch - 2.days).to_date

      engine = subject.new program: program, patient: patient, retro_date: epoch
      date = engine.next_appointment_date[:appointment_date]
      expect(date).to eq(expected_date)
    end
  end
end