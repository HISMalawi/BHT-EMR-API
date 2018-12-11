# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ARTService::RegimenEngine do
  let(:regimen_service) { ARTService::RegimenEngine.new program: program('HIV Program') }
  let(:patient) { create :patient }
  let(:vitals_encounter) { create :encounter_vitals, patient: patient }

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

    it 'retrieves paed. regimens only for weights < 6' do
      created_patient = create_patient(weight: 5.9, age: 3, gender: 'M')
      regimens = regimen_service.find_regimens created_patient

      expect(regimens.size).to eq(3)

      expect(lambda {
        regimens.each do |regimen, _drugs|
          # TODO: This ought to be expanded to check if the correct drugs are
          # being returned for each regimen
          break false unless regimen =~ /^[029]{1}P$/i
        end
      }.call).not_to be false
    end

    it 'retrieves regimens up to 12A for women under 45 years' do
      patient = create_patient(age: 30, weight: 50, gender: 'F')
      regimens = regimen_service.find_regimens patient
      expected_regimens = %w[0A 2A 4A 5A 6A 7A 8A 9A 10A 11A 12A]

      expect(regimens.size).to be expected_regimens.size
      regimens.keys.each { |k| expect(expected_regimens).to include k }
    end

    it 'retrieves regimens up to 15A for women above 45 years' do
      patient = create_patient(age: 45, weight: 50, gender: 'F')
      regimens = regimen_service.find_regimens patient
      expected_regimens = %w[0A 2A 4A 5A 6A 7A 8A 9A 10A 11A 12A 13A 14A 15A]

      expect(regimens.size).to be expected_regimens.size
      regimens.keys.each { |k| expect(expected_regimens).to include k }
    end

    it 'retrieves regimens [0A 2A 4A 9A 11A] for women under 30 kilos' do
      patient = create_patient(age: 30, weight: '29', gender: 'F')
      regimens = regimen_service.find_regimens patient
      expected_regimens = %w[0A 2A 4A 9A 11A]

      expect(regimens.size).to be expected_regimens.size
      regimens.keys.each { |k| expect(expected_regimens).to include k }
    end

    it 'retrieves all regimens below 12A for women below 35 years and between at least 35 kilos' do
      patient = create_patient(age: 30, weight: 35, gender: 'F')
      regimens = regimen_service.find_regimens(patient)

      expected_regimens = %w[0A 2A 4A 5A 6A 7A 8A 9A 10A 11A 12A]

      expect(regimens.size).to be expected_regimens.size
      regimens.keys.each { |k| expect(expected_regimens).to include k }
    end

    it 'retrieves regimens 13A, 14A, 15A for women below 45 years but under a permanent family planning method' do
      patient = create_patient(age: 30, weight: 60, gender: 'F')
      Observation.create(concept: concept('Tubal ligation'), encounter: vitals_encounter,
                         person: patient.person, value_coded: concept('Yes').concept_id)

      regimens = regimen_service.find_regimens(patient)

      expected_regimens = %w[13A 14A 15A]

      expected_regimens.each { |k| expect(regimens).to include(k) }
    end

    it 'skips regimens 13A, 14A, and 15A for women above 45 years but pregnant' do
      patient = create_patient(age: 50, weight: 60, gender: 'F')
      Observation.create(concept: concept('Patient pregnant'), encounter: vitals_encounter,
                         person: patient.person, value_coded: concept('Yes').concept_id)

      regimens = regimen_service.find_regimens(patient)

      expected_regimens = %w[13A 14A 15A]

      expected_regimens.each { |k| expect(regimens).not_to include(k) }
    end

    it 'retrieves regimens [0A 2A 4A 9A 11A] for men under 30 kilos' do
      patient = create_patient(age: 30, weight: 29, gender: 'M')
      regimens = regimen_service.find_regimens(patient)

      expected_regimens = %w[0A 2A 4A 9A 11A]

      expect(regimens.size).to be expected_regimens.size
      regimens.keys.each { |k| expect(expected_regimens).to include k }
    end

    it 'retrieves all regimens for men at least 35 kilos' do
      patient = create_patient(age: 30, weight: 35, gender: 'M')
      regimens = regimen_service.find_regimens(patient)

      expected_regimens = %w[0A 2A 4A 5A 6A 7A 8A 9A 10A 11A 12A 13A 14A 15A]

      expect(regimens.size).to be expected_regimens.size
      regimens.keys.each { |k| expect(expected_regimens).to include k }
    end
  end
end
