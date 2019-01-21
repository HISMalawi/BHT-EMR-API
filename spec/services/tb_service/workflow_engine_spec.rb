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
    it 'returns TB REGISTRATION for patient not in TB programme' do
      
      encounter_type = engine.next_encounter
      expect(encounter_type.name.upcase).to eq('TB REGISTRATION')
    end

    it 'returns TB REGISTRATION for new TB patient' do
      enroll_patient patient
      encounter_type = engine.next_encounter
      expect(encounter_type.name.upcase).to eq('TB REGISTRATION')
    end

    it 'skips TB REGISTRATION for previously registered patient on new visit' do
      register_patient patient, epoch - 100.days
      encounter_type = engine.next_encounter
      expect(encounter_type.name.upcase).to eq('TB RECEPTION')
    end

    it 'returns TB RECEPTION after TB REGISTRATION' do
      register_patient patient
      encounter_type = engine.next_encounter
      expect(encounter_type.name.upcase).to eq('TB RECEPTION')
    end

    it 'starts with TB RECEPTION for visiting patients' do
      register_patient patient
      Observation.create(person: patient.person,
                         concept: concept('Type of patient'),
                         value_coded: concept('External consultation').concept_id)
      encounter_type = engine.next_encounter
      expect(encounter_type.name.upcase).to eq('TB RECEPTION')
    end

    it 'returns VITALS after TB RECEPTION with patient' do
      receive_patient patient, guardian_only: false
      encounter_type = engine.next_encounter
      p encounter_type
      expect(encounter_type.name.upcase).to eq('VITALS')
    end

  end

  # Helpers methods
  def enroll_patient(patient)
    create :patient_program, patient: patient,
                             program: tb_program
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
