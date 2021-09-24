# frozen_string_literal: true

require 'rails_helper'

ACTIVITIES = 'ART adherence, Drug Dispensations, HIV clinic consultations,
              HIV first visits, HIV reception visits, HIV staging visits,
              Manage Appointments, Prescriptions, Vitals'

HIV_PROGRAM_ID = 1

describe ARTService::WorkflowEngine do
  let(:epoch) { Time.now }
  let(:art_program) { Program.find_by_name!('HIV Program') }
  let(:patient) { create :patient }
  let(:engine) do
    UserProperty.create(user: User.current, property: 'Activities', property_value: ACTIVITIES)
    ARTService::WorkflowEngine.new program: art_program,
                                   patient: patient,
                                   date: epoch
  end

  let(:no_activity_engine) do
    # Initialise an engine without any user activities
    UserProperty.find_by(property: 'Activities')&.delete

    ARTService::WorkflowEngine.new program: art_program,
                                   patient: patient,
                                   date: epoch
  end

  let(:constrained_engine) { raise :not_implemented }

  describe :next_encounter do
    it 'returns nil if no activity is enabled' do
      expect(engine.next_encounter).not_to be_nil
      expect(no_activity_engine.next_encounter).to be_nil
    end

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
                         concept_id: ConceptName.find_by_name!('Type of patient').concept_id,
                         value_coded: ConceptName.find_by_name!('External consultation').concept_id)
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
      create :encounter, encounter_type: EncounterType.find_by_name!('HIV Staging').encounter_type_id,
                         encounter_datetime: epoch - 100.days,
                         patient_id: patient.patient_id,
                         program_id: HIV_PROGRAM_ID
      encounter_type = engine.next_encounter
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
                         concept_id: ConceptName.find_by_name!('Fast').concept_id,
                         obs_datetime: Time.now,
                         value_coded: ConceptName.find_by_name!('Yes').concept_id
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

    it 'skips FAST TRACK ASSESSMENT for patients on fast track' do
      treatment = record_treatment patient, assess_fast_track: true
      Observation.create person: patient.person, encounter: treatment,
                         concept_id: ConceptName.find_by_name!('Fast').concept_id,
                         obs_datetime: Time.now,
                         value_coded: ConceptName.find_by_name!('Yes').concept_id
      expect(engine.next_encounter.name.upcase).to eq('DISPENSING')
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

  # Helper methods
  def enroll_patient(patient)
    create :patient_program, patient: patient,
                             program: art_program
  end

  def register_patient(patient, date = nil)
    date ||= Time.now
    enroll_patient patient
    create :encounter, type: EncounterType.find_by_name!('HIV CLINIC REGISTRATION'),
                       patient: patient,
                       date_created: date,
                       program_id: HIV_PROGRAM_ID
  end

  def receive_patient(patient, guardian_only: false, on_fast_track: false)
    register_patient patient
    reception = create :encounter, type: EncounterType.find_by_name!('HIV RECEPTION'),
                                   patient: patient,
                                   program_id: HIV_PROGRAM_ID
    if guardian_only
      create :observation, concept_id: ConceptName.find_by_name!('PATIENT PRESENT').concept_id,
                           encounter: reception,
                           value_coded: ConceptName.find_by_name!('No').concept_id,
                           person: patient.person
    else
      create :observation, concept_id: ConceptName.find_by_name!('PATIENT PRESENT').concept_id,
                           encounter: reception,
                           value_coded: ConceptName.find_by_name!('Yes').concept_id,
                           person: patient.person
    end

    if on_fast_track
      create :observation, concept_id: ConceptName.find_by_name!('Fast').concept_id,
                           encounter: reception,
                           person: patient.person,
                           value_coded: ConceptName.find_by_name!('Yes').concept_id
    end

    create :observation, concept_id: ConceptName.joins(:concept).find_by_name!('Guardian present').concept_id,
                         encounter: reception,
                         value_coded: ConceptName.find_by_name!('Yes').concept_id,
                         person: patient.person

    reception
  end

  def record_vitals(patient)
    receive_patient patient, guardian_only: false

    encounter = create :encounter, type: EncounterType.find_by_name!('VITALS'),
                                   patient: patient,
                                   program_id: HIV_PROGRAM_ID

    create :observation, encounter: encounter,
                         person_id: encounter.patient_id,
                         concept_id: ConceptName.find_by_name!('Weight').concept_id,
                         value_numeric: 50

    create :observation, encounter: encounter,
                         person_id: encounter.patient_id,
                         concept_id: ConceptName.find_by_name!('Height (cm)').concept_id,
                         value_numeric: 50
  end

  def record_staging(patient)
    record_vitals patient
    create :encounter, type: EncounterType.find_by_name!('HIV STAGING'),
                       patient: patient,
                       program_id: HIV_PROGRAM_ID
  end

  def record_hiv_clinic_consultation(patient)
    record_staging patient
    create :encounter, type: EncounterType.find_by_name!('HIV CLINIC CONSULTATION'),
                       patient: patient,
                       program_id: HIV_PROGRAM_ID
  end

  def record_art_adherence(patient)
    record_hiv_clinic_consultation patient
    create :encounter, type: EncounterType.find_by_name!('ART ADHERENCE'),
                       patient: patient,
                       program_id: HIV_PROGRAM_ID
  end

  def record_treatment(patient, assess_fast_track: false)
    record_art_adherence patient
    encounter = create :encounter, type: EncounterType.find_by_name!('TREATMENT'),
                                   patient: patient,
                                   program_id: HIV_PROGRAM_ID

    arv = Drug.arv_drugs[0]
    order = create :order, concept: arv.concept, patient: patient,
                           encounter: encounter
    create :drug_order, order: order, drug: arv

    setup_fast_track_assessment(encounter, patient, assess_fast_track)

    encounter
  end

  def setup_fast_track_assessment(encounter, patient, assess_fast_track)
    assess_fast_track_answer = if assess_fast_track
                                 create :global_property, property: 'enable.fast.track',
                                                          property_value: 'true'
                                 ConceptName.find_by_name!('Yes').concept_id
                               else
                                 ConceptName.find_by_name!('No').concept_id
                               end

    create :observation, concept_id: ConceptName.find_by_name!('Assess for fast track?').concept_id,
                         encounter: encounter,
                         person: patient.person,
                         value_coded: assess_fast_track_answer
  end

  def record_fast_track(patient)
    record_treatment patient, assess_fast_track: true

    encounter = create :encounter, type: EncounterType.find_by_name!('FAST TRACK ASSESMENT'),
                                   patient: patient,
                                   program_id: HIV_PROGRAM_ID
    create :observation, concept_id: ConceptName.find_by_name!('Adult 18 years +').concept_id,
                         person: patient.person,
                         encounter: encounter
  end

  def record_dispensing(patient)
    record_fast_track patient
    create :encounter, type: EncounterType.find_by_name!('DISPENSING'),
                       patient: patient,
                       program_id: HIV_PROGRAM_ID
  end

  def record_appointment(patient)
    record_dispensing patient
    create :encounter, type: EncounterType.find_by_name!('APPOINTMENT'),
                       patient: patient,
                       program_id: HIV_PROGRAM_ID
  end

  def prescribe_arv(patient, date = nil)
    date ||= Time.now

    create :observation, person: patient.person,
                         encounter: create(:encounter_dispensing, patient: patient, program_id: HIV_PROGRAM_ID),
                         concept_id: ConceptName.find_by_name!('AMOUNT DISPENSED').concept_id,
                         value_drug: Drug.arv_drugs[0].drug_id,
                         obs_datetime: date
  end

  def record_patient_not_receiving_treatment(patient)
    create :observation, person: patient.person,
                         encounter: create(:encounter_vitals, patient: patient, program_id: HIV_PROGRAM_ID),
                         concept_id: ConceptName.find_by_name!('Prescribe drugs').concept_id,
                         value_coded: ConceptName.find_by_name!('No').concept_id
  end
end
