# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EncounterService do
  let(:encounter_service) { EncounterService.new }
  let(:patient) { create :patient }
  let(:type) { EncounterType.first }
  let(:encounter_datetime) { Time.now }
  let(:provider) { nil }
  let(:program) { Program.first}

  describe :create do
    it "creates new encounter if a matching encounter doesn't already exist" do
      expect(Encounter.all).to be_empty
      
      created = encounter_service.create(patient: patient, type: type,
                                         encounter_datetime: encounter_datetime,
                                         provider: provider, program: program)
      
      retrieved = Encounter.all
      expect(retrieved.size).to be(1)
      expect(retrieved[0]).to eq(created)
    end

    it 'does not create a new encounter for existing encounter' do
      original = encounter_service.create(patient: patient, type: type,
                                          encounter_datetime: encounter_datetime,
                                          provider: provider, program: program)

      copy = encounter_service.create(patient: patient, type: type,
                                      encounter_datetime: encounter_datetime,
                                      provider: provider, program: program)
      expect(copy).to eq(original)
    end

    it "won't create encounter if patient is not provided" do
      rejected = encounter_service.create(patient: nil, type: type,
                                          encounter_datetime: encounter_datetime,
                                          provider: provider, program: program)
      expect(rejected.errors).not_to be_empty
      expect(rejected.errors[:patient]).not_to be_nil
      expect(Encounter.all).to be_empty
    end

    it 'will autogenerate encounter_datetime if not provided' do
      created = encounter_service.create(patient: patient, type: type,
                               encounter_datetime: nil,
                               provider: provider, program: program)

      encounters = Encounter.all
      expect(encounters.size).to eq(1)
      expect(encounters[0].encounter_datetime).to be > Time.now - 1.minute
    end

    it 'will Update From one Encounter to another' do

      created_encounter = encounter_service.create(patient: patient, type: type,
                               encounter_datetime: nil,
                               provider: provider, program: fetch_program('HIV PROGRAM'))
      updated = encounter_service.update(created_encounter, patient: patient,type: type,
                                encounter_datetime: nil,
                                provider: provider, program: fetch_program('TB PROGRAM'))

      program = Program.find(updated.program_id)
      expect(program.name).to eq(fetch_program('TB PROGRAM').name)
    end

  end

  describe :update do
    let(:new_patient) { create :patient }
    let(:new_type) { EncounterType.last }
    let(:new_encounter_datetime) { Time.now + 10.days }
    let(:new_provider) { User.first.person }

    it 'updates patient' do
      created = encounter_service.create(patient: patient, type: type,
                                         encounter_datetime: encounter_datetime,
                                         provider: provider, program: program)
      updated = encounter_service.update(created, patient: new_patient, program: program)

      encounters = Encounter.all
      expect(encounters.size).to eq(1)
      expect(encounters[0].patient).to eq(new_patient)
    end
  end

  describe :void do
    it 'deletes encounter' do
      created = encounter_service.create(patient: patient, type: type,
                               encounter_datetime: encounter_datetime,
                               provider: provider, program: program)
    
      delete_encounter = -> { encounter_service.void(Encounter.first, 'No reason') }

      encounter_count = -> { Encounter.count }

      expect(&delete_encounter).to change(&encounter_count).from(1).to(0)
    end
  end

  describe :recent_encounter do
    it 'retrieves the most recent encounter for a given patient and type' do
      created = encounter_service.create(patient: patient, type: type,
                                         encounter_datetime: encounter_datetime,
                                         provider: provider, program: program)

      retrieved = EncounterService.recent_encounter(encounter_type_name: created.type.name,
                                                    patient_id: created.patient_id)
      
      expect(retrieved).to eq(created)
    end
  end
end

#Helpers

def fetch_program(name)
  program = Program.find_by(name: name)
  program
end
