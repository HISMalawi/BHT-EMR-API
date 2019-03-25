# frozen_string_literal: true
require 'rails_helper'
require_relative '../../../app/services/drug_order_service'
require_relative '../../../app/services/nlims'

describe TBService::RegimenEngine do
	include ModelUtils
	include DrugOrderService

  let(:date) { Time.now }
  let(:program) { Program.find_by_name 'TB PROGRAM' }
  let(:engine) do
    TBService::RegimenEngine.new program: program
  end 
	let(:person) do 
		Person.create( birthdate: date, gender: 'M' )  
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
		encounter_type: EncounterType.find_by_name('TB REGISTRATION').encounter_type_id, 
		program_id: program.program_id, encounter_datetime: date, 
		date_created: Time.now, creator: 1, provider_id: 1, location_id: 700) 
  end
  
	describe 'TB Patient regimen' do
		
		#find_dosages(patient, date = Date.today)

		it 'returns patient dosage' do
			#need program and patient
			#patient_current_state
			
			program
			person
      person_name
      patient
      patient_identifier_type
			patient_identifier

			patient_state_service = PatientStateService.new
			patient_program = PatientProgram.create(patient_id: patient.patient_id , program_id: program.program_id, date_enrolled: Date.today, creator: 1, uuid: "a", location_id: 701 )
			patient_state = patient_state_service.create_patient_state(program, patient, 92, Time.now)

			prescribe_drugs_ob = prescribe_drugs(patient, encounter)
			medication_order_ob = medication_orders(patient, encounter)
			patient_weight_ob = patient_weight(patient, encounter)
	
			drug1 = {
				drug_inventory_id: 985,
				dose: '1',
				frequency: '1',
				prn: '1',
				units: 'mg',
				equivalent_daily_dose: '1',
				quantity: 10,
				start_date: Date.today,
				auto_expire_date: Date.today
			}

			drug2 = {
				drug_inventory_id: 986,
				dose: '1',
				frequency: '1',
				prn: '1',
				units: 'mg',
				equivalent_daily_dose: '1',
				quantity: 10,
				start_date: Date.today,
				auto_expire_date: Date.today
			}

			drug3 = {
				drug_inventory_id: 987,
				dose: '1',
				frequency: '1',
				prn: '1',
				units: 'mg',
				equivalent_daily_dose: '1',
				quantity: 10,
				start_date: Date.today,
				auto_expire_date: Date.today
			}

			drugs = []
			drugs << drug1
			drugs << drug2
			drugs << drug3
			drugs


			#create drug order
			drug_order  = DrugOrderService.create_drug_orders(encounter: encounter, drug_orders: drugs)

			p patient_dosages = engine.find_dosages(patient, date = Date.today)
			
      # test_types = engine.types(search_string: "TB Tests")
      # expect(test_types.include?('TB Tests')).to eq(true)
      
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

	def create_encounter(patient) 
		encounter = create :encounter, type: encounter_type('TB REGISTRATION'),
																	 patient: patient
		encounter
	end

	def patient_weight(patient, encounter)
		create :observation, concept: concept('Weight'),
                          encounter: encounter,
                          person: patient.person,
                          value_numeric: 70
	end
	
	def prescribe_drugs(patient, encounter)
		create :observation, concept: concept('Prescribe drugs'),
                          encounter: encounter,
                          person: patient.person,
                          value_coded: concept('Yes').concept_id
	end

	def medication_orders(patient, encounter)
		#Isoniazid (H) Rifampicin (R) Pyrazinamide (Z)
		create :observation, concept: concept('Medication orders'),
                          encounter: encounter,
                          person: patient.person,
													value_coded: concept('Rifampicin isoniazid and pyrazinamide').concept_id
												
		create :observation, concept: concept('Medication orders'),
                          encounter: encounter,
                          person: patient.person,
													value_coded: concept('Ethambutol').concept_id
		create :observation, concept: concept('Medication orders'),
                          encounter: encounter,
                          person: patient.person,
													value_coded: concept('Rifampicin and isoniazid').concept_id
		create :observation, concept: concept('Medication orders'),
                          encounter: encounter,
                          person: patient.person,
                          value_coded: concept('Rifampicin Isoniazid Pyrazinamide Ethambutol').concept_id
	end
  
	
end
