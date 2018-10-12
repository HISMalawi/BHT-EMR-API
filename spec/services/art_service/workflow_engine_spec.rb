# frozen_string_literal: true

require 'rails_helper'

describe ARTService::WorkflowEngine do
  let(:art_program) { program 'HIV Program' }
  let(:patient) { create :patient }
  let(:engine) do
    ARTService::WorkflowEngine.new program: art_program,
                                   patient: patient,
                                   date: Time.now
  end
  let(:constrained_engine) { raise :not_implemented }

  def enroll_patient(patient)
    create :patient_program, patient: patient,
                             program: art_program
  end

  def register_patient(patient)
    enroll_patient patient
    create :encounter, type: encounter_type('HIV CLINIC REGISTRATION'),
                       patient: patient
  end

  def receive_patient(patient, guardian_only: false)
    register_patient patient
    reception = create :encounter, type: encounter_type('HIV RECEPTION'),
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

    create :observation, concept: concept('Guardian present'),
                         encounter: reception,
                         value_coded: concept('Yes'),
                         person: patient.person
    reception
  end

  def record_vitals(patient)
    receive_patient patient, guardian_only: false
    create :encounter, type: encounter_type('VITALS'),
                       patient: patient
  end

  describe :next_encounter do
    it 'returns HIV CLINIC REGISTRATION for patient not in ART programme' do
      encounter_type = engine.next_encounter
      expect(encounter_type.name.upcase).to eq('HIV CLINIC REGISTRATION')
    end

    it 'returns HIV CLINIC REGISTRATION for new ART patient' do
      enroll_patient patient
      encounter_type = engine.next_encounter
      expect(encounter_type.name.upcase).to eq('HIV CLINIC REGISTRATION')
    end

    it 'returns HIV_RECEPTION after HIV CLINIC REGISTRATION' do
      # Enroll patient in program...
      create :patient_program, patient: patient,
                               program: art_program

      create :encounter, type: encounter_type('HIV CLINIC REGISTRATION'),
                         patient: patient

      encounter_type = engine.next_encounter
      expect(encounter_type.name.upcase).to eq('HIV RECEPTION')
    end

    it 'returns HIV STAGING after HIV RECEIPTION without patient' do
      receive_patient patient, guardian_only: true
      encounter_type = engine.next_encounter
      expect(encounter_type.name.upcase).to eq('HIV STAGING')
    end

    it 'returns VITALS after HIV RECEPTION with patient' do
      receive_patient patient, guardian_only: false
      encounter_type = engine.next_encounter
      expect(encounter_type.name.upcase).to eq('VITALS')
    end

    it 'returns HIV_STAGING for patients with VITALS' do
      record_vitals patient
      encounter_type = engine.next_encounter
      expect(encounter_type.name.upcase).to eq('HIV STAGING')
    end
  end
end
