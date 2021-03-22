# frozen_string_literal: true
require 'rails_helper'

describe TBService::LabTestsEngine do
  let(:date) { Time.now }
  let(:program) { Program.find_by_name 'TB PROGRAM' }
  let(:engine) do
    TBService::LabTestsEngine.new program: program
  end
	let(:person) do Person.create( birthdate: date, gender: 'M' )
  end
  let(:person_name) do
    PersonName.create(person_id: person.person_id, given_name: 'John',
      family_name: 'Doe')
  end
  let(:patient) { Patient.create( patient_id: person.person_id ) }
  let(:patient_identifier_type) { PatientIdentifierType.find_by_name('national id').id }
	let(:patient_identifier) do
		PatientIdentifier.create(patient_id: patient.patient_id, identifier: 'P170000000013',
			identifier_type: patient_identifier_type,
			date_created: Time.now, creator: 1, location_id: 700)
	end
  let(:encounter) do Encounter.create(patient: patient,
		encounter_type: EncounterType.find_by_name('TB_INITIAL').encounter_type_id,
		program_id: program.program_id, encounter_datetime: date,
		date_created: Time.now, creator: 1, provider_id: 1, location_id: 700)
  end

  describe 'Lab Test Engine' do

    it 'returns all tests types from LIMS' do
      require_relative './nlims_mock'

      test_types = engine.types(search_string: "TB Tests")
      expect(test_types.include?('TB Tests')).to eq(true)

    end

    it 'returns specimen types for particular test type from LIMS' do
      require_relative './nlims_mock'

      test_types = engine.types(search_string: "TB Tests")
      specimen_types = engine.panels(test_types.first)
      expect(specimen_types.include?('Sputum')).to eq(true)

    end

    it 'returns created lab order' do
      require_relative './nlims_mock'

      person
      person_name
      patient
      patient_identifier_type
      patient_identifier
      encounter
      test_types = engine.types(search_string: "TB Tests")
      specimen_types = engine.panels(test_types.first) #specimen type

      sample_type = specimen_types.select { |type| type == 'Sputum'  }
      tests = [
        {
          "test_type" => test_types.first,
          "reason" => "Patient a TB Suspect",
          "sample_type" => sample_type,
          "sample_status" => "Spec Sample Status",
          "target_lab" => "Spec TB Lab 1",
          "recommended_examination" => "Spec GeneXpert",
          "treatment_history" => "Spec New",
          "sample_date" => Time.now,
          "sending_facility" => "Spec TB Reception", #remove this
          "time_line" => "NA" #could be follow
        }
      ]
      user = person
      order = engine.create_order(encounter: encounter, date: date, tests: tests, requesting_clinician: user.person_id)
      expect(order)

		end

  end
end
