# frozen_string_literal: true

require 'rails_helper'
require_relative '../../../app/services/drug_order_service'
require_relative '../../../app/services/dispensation_service'

describe TBService::PatientsEngine do
	include DrugOrderService
	include ModelUtils

  let(:epoch) { Time.now }
	let(:tb_program) { program 'TB PROGRAM' }
	let(:person) do 
		Person.create( birthdate: epoch, gender: 'M' )  
  end
  let(:person_name) do
    PersonName.create(person_id: person.person_id, given_name: 'John', 
      family_name: 'Doe')
  end
	let(:patient) { create :patient }
	let(:patient_identifier_type) { PatientIdentifierType.find_by_name('National id').id }
	let(:patient_identifier) do 
		PatientIdentifier.create(patient_id: patient.patient_id, identifier: 'P170000000013', 
			identifier_type: patient_identifier_type, 
			date_created: Time.now, creator: 1, location_id: 700) 
	end
  let(:engine) do
    TBService::PatientsEngine.new program: tb_program
  end

  
  let(:constrained_engine) { raise :not_implemented }

  describe 'patients engine' do

		it 'returns drugs patient receieved' do

			encounter = treatment_encounter(patient)

			epoch = Time.now
			
			patient_state_service = PatientStateService.new
			patient_program = PatientProgram.create(patient_id: patient.patient_id , program_id: tb_program.program_id, date_enrolled: Date.today, creator: 1, uuid: "a", location_id: 701 )
			patient_state = patient_state_service.create_patient_state(tb_program, patient, 92, Time.now)

			prescribe_drugs_ob = prescribe_drugs(patient, encounter)
			medication_order_ob = medication_orders(patient, encounter)
			patient_weight_ob = patient_weight(patient, encounter)

			drug_quantity = 10
			
			drugs = [
				{
				drug_inventory_id: 103,
				dose: '1',
				frequency: '1',
				prn: '1',
				units: 'mg',
				equivalent_daily_dose: '1',
				quantity: drug_quantity,
				start_date: Date.today,
				auto_expire_date: Date.today
				}
			]

			drug_orders  = DrugOrderService.create_drug_orders(encounter: encounter, drug_orders: drugs)
			plain_despenation = [
				{
					drug_order_id: drug_orders[0][:order_id],
					quantity: drug_quantity
				}
			]

			dispensed = DispensationService.create(plain_despenation)

			drugs_receieved = engine.patient_last_drugs_received(patient, epoch)
			expect(drugs_receieved[0][:drug_inventory_id]).to eq(103)
		end
		
		it 'returns patient summary' do

			tb_program
			person
      person_name
      patient
      patient_identifier_type
			patient_identifier

			encounter = treatment_encounter(patient)

			epoch = Time.now
			
			patient_state_service = PatientStateService.new
			patient_program = PatientProgram.create(patient_id: patient.patient_id , program_id: tb_program.program_id, date_enrolled: Date.today, creator: 1, uuid: "a", location_id: 701 )
			patient_state = patient_state_service.create_patient_state(tb_program, patient, 92, Time.now)

			prescribe_drugs_ob = prescribe_drugs(patient, encounter)
			medication_order_ob = medication_orders(patient, encounter)
			patient_weight_ob = patient_weight(patient, encounter)

			drug_quantity = 10
			
			drugs = [
				{
				drug_inventory_id: 103,
				dose: '1',
				frequency: '1',
				prn: '1',
				units: 'mg',
				equivalent_daily_dose: '1',
				quantity: drug_quantity,
				start_date: Date.today,
				auto_expire_date: Date.today
				}
			]

			drug_orders  = DrugOrderService.create_drug_orders(encounter: encounter, drug_orders: drugs)
			plain_despenation = [
				{
					drug_order_id: drug_orders[0][:order_id],
					quantity: drug_quantity
				}
			]

			dispensed = DispensationService.create(plain_despenation)

			patient_summary = engine.patient(patient.patient_id, epoch)
			expect(patient_summary[:patient_id]).to eq(patient.patient_id)
    end

  end

  # Helpers methods

  def treatment_encounter(patient)
    treatment = create :encounter, type: encounter_type('DISPENSING'),
                                   patient: patient, program_id: tb_program.program_id 
    treatment
	end
	
	def patient_weight(patient, encounter)
		create :observation, concept: concept('Weight'),
                          encounter: encounter,
                          person: patient.person,
                          value_numeric: 6
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
	end

end
