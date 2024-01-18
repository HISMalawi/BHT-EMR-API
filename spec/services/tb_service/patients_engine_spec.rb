# frozen_string_literal: true

require 'rails_helper'
require_relative '../../../app/services/drug_order_service'
require_relative '../../../app/services/dispensation_service'

describe TbService::PatientsEngine do
	include DrugOrderService

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
    TbService::PatientsEngine.new program: tb_program
	end

  let(:drug_quantity) {10}

  let(:constrained_engine) { raise :not_implemented }

  describe 'patients engine' do

		it 'returns drugs patient receieved' do
			epoch = Time.now

			patient_state_service = PatientStateService.new
			patient_program = PatientProgram.create(patient_id: patient.patient_id , program_id: tb_program.program_id, date_enrolled: Date.today, creator: 1, uuid: "a", location_id: 701 )
			patient_state = patient_state_service.create_patient_state(tb_program, patient, 92, Time.now)
			dispensation()
			drugs_receieved = engine.patient_last_drugs_received(patient, epoch)
			expect(drugs_receieved[0][:drug_inventory_id]).to eq(103)
		end

		it 'returns patient summary' do
      patient
      epoch = Time.now
			patient_state_service = PatientStateService.new
			patient_program = PatientProgram.create(patient_id: patient.patient_id , program_id: tb_program.program_id, date_enrolled: Date.today, creator: 1, uuid: "a", location_id: 701 )
			patient_state = patient_state_service.create_patient_state(tb_program, patient, 92, Time.now)
      dispensation()
      engine.assign_tb_number(patient.patient_id, Time.now)
			patient_summary = engine.patient(patient.patient_id, epoch)
			expect(patient_summary[:patient_id]).to eq(patient.patient_id)
    end

  end

  # Helpers methods

	def treatment_encounter(patient, datetime)
    treatment = create :encounter, type: encounter_type('TREATMENT'),
                                   patient: patient, program_id: tb_program.program_id, encounter_datetime: datetime
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

	def lab_orders_encounter(patient, datetime)
    lab_order = create :encounter, type: encounter_type('LAB ORDERS'),
                                   patient: patient, program_id: tb_program.program_id, encounter_datetime: datetime
    lab_order
	end

	def lab_result_encounter(patient, datetime)
    encounter = create :encounter, type: encounter_type('LAB RESULTS'),
    patient: patient, program_id: tb_program.program_id, encounter_datetime: datetime
    encounter
  end

	def record_vitals(patient, datetime)
    vitals = create :encounter, type: encounter_type('VITALS'),
                                   patient: patient, program_id: tb_program.program_id, encounter_datetime: datetime
    vitals
  end

	def tb_status(patient, encounter, status)

		create :observation, concept: concept('TB status'),
                          encounter: encounter,
                          person: patient.person,
													value_coded: concept(status).concept_id
  end

	def drugs
    [
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
  end

  def dispense(drug_orders)
    [
      {
        drug_order_id: drug_orders[0][:order_id],
        quantity: drug_quantity
      }
    ]
  end

  def dispensation
      encounter = lab_orders_encounter(patient, Time.now - 2.hour)
      tb_status(patient, lab_result_encounter(patient, Time.now), "Positive")
      record_vitals(patient, Time.now)
      prescribe_drugs(patient, encounter)
      medication_orders(patient, encounter)
      patient_weight(patient, encounter)

      drug_orders  = DrugOrderService.create_drug_orders(encounter: treatment_encounter(patient, Time.now), drug_orders: drugs())
			plain_despenation = dispense(drug_orders)
      DispensationService.create(tb_program, plain_despenation)
  end

end
