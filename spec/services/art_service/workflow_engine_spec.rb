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

  describe :next_encounter do
    it 'returns HIV_CLINIC_REGISTRATION for new patient' do
      encounter_type = engine.next_encounter
      expect(encounter_type.name.upcase).to eq('HIV CLINIC REGISTRATION')
    end

    it 'returns HIV_RECEPTION for registered patient' do
      # Enroll patient in program...
      create :patient_program, patient: patient,
                               program: art_program

      create :encounter, type: encounter_type('HIV CLINIC REGISTRATION'),
                         patient: patient

      encounter_type = engine.next_encounter
      expect(encounter_type.name.upcase).to eq('HIV RECEPTION')
    end

    it 'returns VITALS for patients with HIV_RECEPTION' do
    end

    it 'returns HIV_STAGING for patients with VITALS' do
    end
  end
end
