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
      lab_request patient
      encounter_type = engine.next_encounter
      expect(encounter_type.name.upcase).to eq('LAB ORDERS')
    end

  end

  # Helpers methods

  def enroll_patient(patient)
    create :patient_program, patient: patient,
                             program: tb_program
  end

  def lab_request(patient)

    program = Program.find_by(name: "TB PROGRAM")

    tb_initial = create :encounter, type: encounter_type('TB_INITIAL'),
                                   patient: patient, program_id: program.program_id 
    tb_initial
  end

  def register_patient(patient, date = nil)
    date ||= Time.now
    enroll_patient patient
    create :encounter, type: encounter_type('TB REGISTRATION'),
                       patient: patient,
                       date_created: date
  end

  def receive_patient(patient, guardian_only: false, on_fast_track: false)
    register_patient patient
    reception = create :encounter, type: encounter_type('TB RECEPTION'),
                                   patient: patient
    if guardian_only
      create :observation, concept: concept('PATIENT PRESENT'),
                           encounter: reception,
                           value_coded: concept('No').concept_id,
                           person: patient.person
    else
      create :observation, concept: concept('PATIENT PRESENT'),
                           encounter: reception,
                           value_coded: concept('Yes').concept_id,
                           person: patient.person
    end

    if on_fast_track
      create :observation, concept: concept('Fast'),
                           encounter: reception,
                           person: patient.person,
                           value_coded: concept('Yes').concept_id
    end

    create :observation, concept: concept('Guardian present'),
                         encounter: reception,
                         value_coded: concept('Yes'),
                         person: patient.person
    reception
  end

end
