# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ARTService::RegimenEngine do
  let(:regimen_service) { ARTService::RegimenEngine.new program: program('HIV Program') }
  let(:patient) { create :patient }
  let(:vitals_encounter) { create :encounter_vitals, patient: patient }
  let(:dtg_ids) { Drug.where(concept_id: ConceptName.find_by_name('Dolutegravir').concept_id).collect(&:drug_id) }

  def set_patient_weight(patient, weight)
    Observation.create(
      concept: concept('Weight'),
      encounter: vitals_encounter,
      person: patient.person,
      obs_datetime: Time.now,
      value_numeric: weight
    )
  end

  def create_patient(weight:, age:, gender:)
    new_patient = patient
    new_patient.person.gender = gender
    set_patient_weight(new_patient, weight)
    new_patient.person.birthdate = age.years.ago
    new_patient
  end

  describe :find_regimens do
    it 'raises ArgumentError if weight and age are not provided' do
      (expect { regimen_service.find_regimens }).to raise_error(ArgumentError)
    end

    it 'retrieves [0P, 2P, 9P, 11P] regimens only for weights < 6' do
      created_patient = create_patient(weight: 5.9, age: 3, gender: 'M')
      regimens = regimen_service.find_regimens created_patient

      expected_regimens = %w[0P 2P 9P 11P]
      expect(regimens.keys).to eq(expected_regimens)
    end

    it 'retrieves all regimens for women under 45 years' do
      # NOTE: Initially women under 45 were limited to regimens 12A,
      # however based on DHA's recommendation it was suggested that
      # no regimens must be filtered out. This test was modified
      # to ensure that this recommendation is being followed. Don't
      # be surprised when you another test that is very similar to
      # this one... It's not a duplicate.
      patient = create_patient(age: 30, weight: 50, gender: 'F')
      regimens = regimen_service.find_regimens patient
      expected_regimens = %w[0A 2A 4A 5A 6A 7A 8A 9A 10A 11A 12A 13A 14A 15A]

      expect(regimens.size).to be expected_regimens.size
      regimens.keys.each { |k| expect(expected_regimens).to include k }
    end

    it 'retrieves all regimens for women above 45 years' do
      patient = create_patient(age: 45, weight: 50, gender: 'F')
      regimens = regimen_service.find_regimens patient
      expected_regimens = %w[0A 2A 4A 5A 6A 7A 8A 9A 10A 11A 12A 13A 14A 15A]

      expect(regimens.size).to be expected_regimens.size
      regimens.keys.each { |k| expect(expected_regimens).to include k }
    end

    it 'retrieves regimens [0A 2A 4P 9P 11P] for women under 30 kilos' do
      patient = create_patient(age: 30, weight: '29', gender: 'F')
      regimens = regimen_service.find_regimens patient
      expected_regimens = Set.new(%w[0A 2A 4P 9P 11P])

      expect(Set.new(regimens.keys)).to eq(expected_regimens)
    end

    it 'retrieves all regimens for women above 35 kilos' do
      patient = create_patient(age: 30, weight: 35, gender: 'F')
      regimens = regimen_service.find_regimens(patient)

      expected_regimens = %w[0A 2A 4A 5A 6A 7A 8A 9A 10A 11A 12A 13A 14A 15A]

      expect(regimens.size).to be expected_regimens.size
      regimens.keys.each { |k| expect(expected_regimens).to include k }
    end

    it 'retrieves regimens [0A 2A 4P 9P 11P] for men under 30 kilos' do
      patient = create_patient(age: 30, weight: 29, gender: 'M')
      regimens = regimen_service.find_regimens(patient)

      expected_regimens = Set.new(%w[0A 2A 4P 9P 11P])

      expect(Set.new(regimens.keys)).to eq(expected_regimens)
      regimens.keys.each { |k| expect(expected_regimens).to include k }
    end

    it 'retrieves all regimens for men at least 35 kilos' do
      patient = create_patient(age: 30, weight: 35, gender: 'M')
      regimens = regimen_service.find_regimens(patient)

      expected_regimens = %w[0A 2A 4A 5A 6A 7A 8A 9A 10A 11A 12A 13A 14A 15A]

      expect(regimens.size).to be expected_regimens.size
      regimens.keys.each { |k| expect(expected_regimens).to include k }
    end

    def put_patient_on_tb_treatment(patient)
      tb_status_concept_id = ConceptName.find_by_name('TB Status').concept_id
      rx_concept_id = concept('Rx').concept_id

      encounter = create(:encounter, program_id: 1, patient: patient)

      create(:observation, person_id: patient.id,
                           concept_id: tb_status_concept_id,
                           encounter_id: encounter.encounter_id,
                           obs_datetime: Time.now,
                           value_coded: rx_concept_id)
    end

    it 'does not double dose DTG for 13A patients not on TB treatment' do
      patient = create_patient(age: 30, weight: 55, gender: 'M')
      regimen = regimen_service.find_regimens(patient)['13A']

      expect(regimen.size).to eq(1)
      expect(dtg_ids).not_to include(regimen[0][:drug_id])
    end

    it 'double doses DTG for 13A patients on TB treatment' do
      patient = create_patient(age: 30, weight: 55, gender: 'M')
      put_patient_on_tb_treatment(patient)

      regimen = regimen_service.find_regimens(patient)['13A']
      expect(regimen.size).to eq(2)

      regimen_dtgs = regimen.select { |drug| dtg_ids.include?(drug[:drug_id]) }

      expect(regimen_dtgs.size).to eq(1)
      expect(regimen_dtgs[0][:am]).to be_zero
      expect(regimen_dtgs[0][:pm]).to be > 0
    end

    it 'does not double dose DTG for 14A patients not on TB treatment' do
      patient = create_patient(age: 40, weight: 60, gender: 'F')
      regimen = regimen_service.find_regimens(patient)['14A']
      regimen_dtgs = regimen.select { |drug| dtg_ids.include?(drug[:drug_id]) }

      expect(regimen_dtgs.size).to eq(1)
      expect(regimen_dtgs[0][:am]).to be > 0
      expect(regimen_dtgs[0][:pm]).to be_zero
    end

    it 'double doses DTG for 14A patients on TB treatment' do
      patient = create_patient(age: 40, weight: 60, gender: 'F')
      put_patient_on_tb_treatment(patient)

      regimen = regimen_service.find_regimens(patient)['14A']
      regimen_dtgs = regimen.select { |drug| dtg_ids.include?(drug[:drug_id]) }

      expect(regimen_dtgs.size).to eq(1)
      expect(regimen_dtgs[0][:am]).to eq(regimen_dtgs[0][:pm])
      expect(regimen_dtgs[0][:am]).to be > 0
      expect(regimen_dtgs[0][:pm]).to be > 0
    end

    it 'does not double dose DTG for 15A patients not on TB treatment' do
      patient = create_patient(age: 40, weight: 60, gender: 'F')
      regimen = regimen_service.find_regimens(patient)['15A']
      regimen_dtgs = regimen.select { |drug| dtg_ids.include?(drug[:drug_id]) }

      expect(regimen_dtgs.size).to eq(1)
      expect(regimen_dtgs[0][:am]).to be > 0
      expect(regimen_dtgs[0][:pm]).to be_zero
    end

    it 'double doses DTG for 15A patients on TB treatment' do
      patient = create_patient(age: 40, weight: 60, gender: 'F')
      put_patient_on_tb_treatment(patient)

      regimen = regimen_service.find_regimens(patient)['15A']
      regimen_dtgs = regimen.select { |drug| dtg_ids.include?(drug[:drug_id]) }

      expect(regimen_dtgs.size).to eq(1)
      expect(regimen_dtgs[0][:am]).to eq(regimen_dtgs[0][:pm])
      expect(regimen_dtgs[0][:am]).to be > 0
      expect(regimen_dtgs[0][:pm]).to be > 0
    end
  end
end
