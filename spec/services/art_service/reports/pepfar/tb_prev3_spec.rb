# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ARTService::Reports::Pepfar::TbPrev3 do
  let(:drug_order) { create(:drug_order, drug: Drug.find(1216), order: order, quantity: 12) }
  let(:start_date) { Date.today - 3.months }
  let(:end_date) { Date.today }
  let(:report) { ARTService::Reports::Pepfar::TbPrev3.new(start_date: start_date, end_date: end_date) }

  # persist data
  before(:all) do
    @person = create(:person)
    @patient = create(:patient, patient_id: @person.id)
    @patient_program = create(:patient_program, patient_id: @patient.id, program: Program.find_by_name('HIV Program'))
    @patient_state = create(:patient_state, patient_program: @patient_program, start_date: Date.today - 6.months)
    # create an HIV CLINIC REGISTRATION encounter
    @encounter = create(:encounter, patient: @patient, encounter_datetime: Date.today - 6.months,
                                    program: Program.find_by_name('HIV Program'), type: EncounterType.find_by_name('HIV CLINIC REGISTRATION'))
    # create an observation with concept Type of patient and the value_coded as New Patient
    @observation = create(:observation, encounter: @encounter, concept: ConceptName.find_by_name('Type of patient').concept,
                                        value_coded: ConceptName.find_by_name('New Patient').concept_id,
                                        obs_datetime: Date.today - 6.months, person: @person)

    @patient_identifier = create(:patient_identifier, patient_id: @patient.id, identifier_type: 4,
                                                      identifier: 'MPC-ARV-1')
    @patient_encounter = create(:encounter_treatment, patient_id: @patient.id,
                                                      encounter_datetime: Date.today - 6.months, program_id: 1)
    @obs_date_started = create(:observation, encounter: @patient_encounter,
                                             concept: ConceptName.find_by_name('Date antiretrovirals started').concept,
                                             value_datetime: Date.today - 6.months, obs_datetime: Date.today - 6.months,
                                             person: @person)
    @order = create(:order, patient: @patient, concept: (ConceptName.find_by_name 'Isoniazid/Rifapentine').concept,
                            encounter: @patient_encounter, start_date: Date.today - 6.months, auto_expire_date: Date.today - 5.months, order_type: OrderType.find_by_name('Drug order'))
    @drug_order = create(:drug_order, drug: Drug.find(1216), order: @order, quantity: 12)

    # dispense ARV drugs
    @arv_order = create(:order, patient: @patient, concept: (ConceptName.find_by_name 'TDF/3TC/DTG').concept,
                                encounter: @patient_encounter, start_date: Date.today - 6.months, auto_expire_date: Date.today - 5.months, order_type: OrderType.find_by_name('Drug order'))
    @arv_drug_order = create(:drug_order,
                             drug: (Drug.find_by_concept_id (ConceptName.find_by_name 'TDF/3TC/DTG').concept_id), order: @arv_order, quantity: 30)
  end

  let(:response) { report.find_report }
  # delete data after all tests are done to avoid cluttering the database
  after(:all) do
    @patient.void('Testing')
  end

  describe :new do
    it 'initializes with start and end dates' do
      expect(report).to be_a(ARTService::Reports::Pepfar::TbPrev3)
    end
  end

  describe :check_date do
    it 'return a date 6 months before the start date' do
      expect(report.check_date).to eq(start_date - 6.months)
    end
  end

  describe :find_report do
    it 'returns a report' do
      # print all the patients
      expect(report.find_report).to be_a(Hash)
    end
  end

  describe :find_report do
    it 'the response should have 15-19 years group' do
      expect(response).to have_key('15-19 years')
    end
  end

  describe :find_report do
    it 'the response should have a hash for 15-19 years group' do
      expect(response['15-19 years']).to be_a(Hash)
    end
  end

  describe :find_report do
    it 'should have a key a key female in the 15-19 years group' do
      expect(response['15-19 years']).to have_key('F')
    end
  end

  describe :find_report do
    it 'should have started_new_on_art under the female key in the 15-19 years group' do
      expect(response['15-19 years']['F']['3HP']).to have_key(:started_new_on_art)
    end
  end

  describe :find_report do
    it 'should have the patient id under the started_new_on_art key in the 15-19 years group' do
      expect(response['15-19 years']['F']['3HP'][:started_new_on_art][0]['patient_id']).to eq(@patient.id)
    end
  end

  describe :patient_tpt_status do
    it 'returns a patient tpt status' do
      expect(report.patient_tpt_status(@patient.id)).to be_a(Hash)
    end
  end
end
