# frozen_string_literal: true

require 'rails_helper'

describe ARTService::WorkflowEngine do
  let(:epoch) { Time.now }
  let(:art_program) { program 'HIV Program' }
  let(:patient) { create :patient }
  let(:engine) do
    ARTService::WorkflowEngine.new program: art_program,
                                   patient: patient,
                                   date: epoch
  end
  let(:constrained_engine) { raise :not_implemented }

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

    it 'skips HIV CLINIC REGISTRATION for previously registered patient on new visit' do
      register_patient patient, epoch - 100.days
      encounter_type = engine.next_encounter
      expect(encounter_type.name.upcase).to eq('HIV RECEPTION')
    end

    it 'returns HIV_RECEPTION after HIV CLINIC REGISTRATION' do
      register_patient patient
      encounter_type = engine.next_encounter
      expect(encounter_type.name.upcase).to eq('HIV RECEPTION')
    end

    it 'starts with HIV_RECEPTION for visiting patients' do
      register_patient patient
      Observation.create(person: patient.person,
                         concept: concept('Type of patient'),
                         value_coded: concept('External consultation').concept_id)
      encounter_type = engine.next_encounter
      expect(encounter_type.name.upcase).to eq('HIV RECEPTION')
    end

    it 'skips VITALS and returns HIV STAGING after HIV RECEIPTION without patient' do
      receive_patient patient, guardian_only: true
      encounter_type = engine.next_encounter
      expect(encounter_type.name.upcase).to eq('HIV STAGING')
    end

    it 'skips VITALS when on FAST TRACK' do
      receive_patient patient, on_fast_track: true
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

    it 'skips HIV STAGING for patients who have undergone staging before' do
      record_vitals patient
      create :encounter, encounter_type: encounter_type('HIV Staging').encounter_type_id,
                         encounter_datetime: epoch - 100.days,
                         patient_id: patient.patient_id
      encounter_type =  engine.next_encounter
      expect(encounter_type.name.upcase).to eq('HIV CLINIC CONSULTATION')
    end

    it 'returns HIV CLINIC CONSULTATION for patients with HIV STAGING' do
      record_staging patient
      encounter_type = engine.next_encounter
      expect(encounter_type.name.upcase).to eq('HIV CLINIC CONSULTATION')
    end

    it 'skips HIV CLINIC CONSULTATION for patients on fast track' do
      staging = record_staging patient
      Observation.create person: patient.person, encounter: staging,
                         concept: concept('Fast'), obs_datetime: Time.now,
                         value_coded: concept('Yes').concept_id
      prescribe_arv patient, epoch - 1000.days
      encounter_type = engine.next_encounter
      expect(encounter_type.name.upcase).to eq('ART ADHERENCE')
    end

    it 'skips ART ADHERENCE and returns TREATMENT for new patient after HIV CLINIC CONSULTATION' do
      record_hiv_clinic_consultation patient
      encounter_type = engine.next_encounter
      expect(encounter_type.name.upcase).to eq('TREATMENT')
    end

    it 'returns ART ADHERENCE after HIV CLINIC CONSULTATION for patient with previously received medication' do
      record_hiv_clinic_consultation patient
      prescribe_arv patient, epoch - 1000.days
      encounter_type = engine.next_encounter
      expect(encounter_type.name.upcase).to eq('ART ADHERENCE')
    end

    it 'returns TREATMENT after ART ADHERENCE' do
      record_art_adherence patient
      encounter_type = engine.next_encounter
      expect(encounter_type.name.upcase).to eq('TREATMENT')
    end

    it 'terminates workflow for patients not getting any treatment' do
      record_art_adherence patient
      record_patient_not_receiving_treatment patient
      encounter_type = engine.next_encounter
      expect(encounter_type).to be_nil
    end

    it 'returns FAST TRACK ASSESMENT after TREATMENT' do
      record_treatment patient, assess_fast_track: true
      encounter_type = engine.next_encounter
      expect(encounter_type.name.upcase).to eq('FAST TRACK ASSESMENT')
    end

    it 'returns DISPENSING after FAST TRACK ASSESMENT' do
      record_fast_track patient
      encounter_type = engine.next_encounter
      expect(encounter_type.name.upcase).to eq('DISPENSING')
    end

    it 'returns APPOINTMENT after DISPENSING' do
      record_dispensing patient
      encounter_type = engine.next_encounter
      expect(encounter_type.name.upcase).to eq('APPOINTMENT')
    end

    it 'returns nil after APPOINTMENT' do
      record_appointment patient
      encounter_type = engine.next_encounter
      expect(encounter_type).to be_nil
    end
  end

  # Helpers methods
  def enroll_patient(patient)
    create :patient_program, patient: patient,
                             program: art_program
  end

  def register_patient(patient, date = nil)
    date ||= Time.now
    enroll_patient patient
    create :encounter, type: encounter_type('HIV CLINIC REGISTRATION'),
                       patient: patient,
                       date_created: date
  end

  def receive_patient(patient, guardian_only: false, on_fast_track: false)
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

  def record_vitals(patient)
    receive_patient patient, guardian_only: false
    create :encounter, type: encounter_type('VITALS'),
                       patient: patient
  end

  def record_staging(patient)
    record_vitals patient
    create :encounter, type: encounter_type('HIV STAGING'),
                       patient: patient
  end

  def record_hiv_clinic_consultation(patient)
    record_staging patient
    create :encounter, type: encounter_type('HIV CLINIC CONSULTATION'),
                       patient: patient
  end

  def record_art_adherence(patient)
    record_hiv_clinic_consultation patient
    create :encounter, type: encounter_type('ART ADHERENCE'),
                       patient: patient
  end

  def record_treatment(patient, assess_fast_track: false)
    record_art_adherence patient
    encounter = create :encounter, type: encounter_type('TREATMENT'),
                                   patient: patient

    arv = Drug.arv_drugs[0]
    order = create :order, concept: arv.concept, patient: patient,
                           encounter: encounter
    create :drug_order, order: order, drug: arv

    # HACK: Fast track encounter's requirement is the existence of a
    # fast track encounter with an observation of 'Assess for fast track?'
    # bound to a 'Yes' concept.
    encounter = create :encounter, type: encounter_type('FAST TRACK ASSESMENT'),
                                   patient: patient

    value_coded = assess_fast_track ? concept('Yes').concept_id : concept('No').concept_id
    create :observation, concept: concept('Assess for fast track?'),
                         encounter: encounter,
                         person: patient.person,
                         value_coded: value_coded
  end

  def record_fast_track(patient)
    record_treatment patient, assess_fast_track: true

    # record_treatment creates a fast track encounter for us,
    # all we need to do is add additional observations for the
    # assessment
    encounter = Encounter.find_by type: encounter_type('FAST TRACK ASSESMENT'),
                                  patient: patient
    create :observation, concept: concept('Adult 18 years +'),
                         person: patient.person,
                         encounter: encounter
  end

  def record_dispensing(patient)
    record_fast_track patient
    create :encounter, type: encounter_type('DISPENSING'),
                       patient: patient
  end

  def record_appointment(patient)
    record_dispensing patient
    create :encounter, type: encounter_type('APPOINTMENT'),
                       patient: patient
  end

  def prescribe_arv(patient, date = nil)
    date ||= Time.now

    create :observation, person: patient.person,
                         encounter: create(:encounter_dispensing, patient: patient),
                         concept: concept('AMOUNT DISPENSED'),
                         value_drug: Drug.arv_drugs[0].drug_id,
                         obs_datetime: date
  end

  def record_patient_not_receiving_treatment(patient)
    create :observation, person: patient.person,
                         encounter: create(:encounter_vitals, patient: patient),
                         concept: concept('Prescribe drugs'),
                         value_coded: concept('No').concept_id
  end
end
