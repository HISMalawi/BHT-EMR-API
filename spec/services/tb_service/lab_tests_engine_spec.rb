# frozen_string_literal: true
require 'rails_helper'
require_relative '../../../app/services/nlims'

describe TBService::LabTestsEngine do
  include ModelUtils

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
		PatientIdentifier.create(patient_id: patient.patient_id, identifier: 'P170000001234', 
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
			
      test_types = engine.types(search_string: "TB Tests")
      expect(test_types.include?('TB Tests')).to eq(true)
      
    end
    
    it 'returns specimen types for particular test type from LIMS' do
      
      test_types = engine.types(search_string: "TB Tests")
      specimen_types = engine.panels(test_types.first)
      expect(specimen_types.include?('Sputum')).to eq(true)
      
    end

    it 'returns created lab order' do
      person
      person_name
      patient
      patient_identifier_type
      patient_identifier
      encounter
      test_types = engine.types(search_string: "TB Tests")
      specimen_types = engine.panels(test_types.first)
      tests = [
        {"test_type" => test_types.first, "reason" => "Patient a TB Suspect"},
        {"test_type" => test_types.first, "reason" => "Another Test"}
      ]
      user = person 
      engine.create_order(encounter: encounter, date: date, tests: tests, requesting_clinician: user.person_id)	
      #expect(response).to have_http_status(:created) # 200
      
		end

  end

  # Helpers methods

  def nlims
    return @nlims if @nlims

    @config = YAML.load_file "#{Rails.root}/config/application.yml"
    @nlims = ::NLims.new config
    @nlims.auth config['lims_default_user'], config['lims_default_password']
    @nlims
  end
  
	
end
