# frozen_string_literal: true

require 'rails_helper'

describe TBService::WorkflowEngine do
  let(:epoch) { Time.now }
  let(:tb_program) { program 'TB PROGRAM' } #look into this
  let(:patient) { create :patient }
  let(:engine) do
    TBService::WorkflowEngine.new program: tb_program,
                                   patient: patient,
                                   date: epoch
  end

  
  let(:constrained_engine) { raise :not_implemented }

  describe :next_encounter do

    #Return TB initial if patient does not exist in

    it 'returns TB_INITIAL REGISTRATION for a patient not a TB suspect in the TB programme' do
  
      encounter_type = engine.next_encounter
      expect(encounter_type.name.upcase).to eq('TB_INITIAL')
    end

    it 'returns TB_INITIAL REGISTRATION for a new TB suspect' do
      enroll_patient patient
      encounter_type = engine.next_encounter
      expect(encounter_type.name.upcase).to eq('TB_INITIAL')
    end

    it 'returns LAB ORDERS for TB suspect with no Lab Request in the TB Programme' do
      tb_initial_encounter patient
      encounter_type = engine.next_encounter
      expect(encounter_type.name.upcase).to eq('LAB ORDERS')
    end

    #return treatment after VITALS
    it 'returns TREATMENT for a TB patient' do
      lab_orders_encounter patient
      encounter_type = engine.next_encounter
      expect(encounter_type.name.upcase).to eq('TREATMENT')
    end

    it 'returns DISPENSING for a TB patient' do
      lab_orders_encounter patient
      treatment_encounter patient
      encounter_type = engine.next_encounter
      expect(encounter_type).to eq(nil)
    end

  end

  # Helpers methods

  def enroll_patient(patient)
    create :patient_program, patient: patient,
                             program: tb_program
  end

  def tb_initial_encounter(patient)
    tb_initial = create :encounter, type: encounter_type('TB_INITIAL'),
                                   patient: patient, program_id: tb_program.program_id 
    tb_initial
  end

  def record_vitals(patient)
    vitals = create :encounter, type: encounter_type('VITALS'),
                                   patient: patient, program_id: tb_program.program_id
    vitals
  end

  def lab_orders_encounter(patient)
    record_vitals patient
    lab_order = create :encounter, type: encounter_type('LAB ORDERS'),
                                   patient: patient, program_id: tb_program.program_id 
    lab_order
  end

  def treatment_encounter(patient)
    treatment = create :encounter, type: encounter_type('TREATMENT'),
                                   patient: patient, program_id: tb_program.program_id 
    treatment
  end

end
