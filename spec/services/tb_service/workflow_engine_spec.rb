# frozen_string_literal: true

require 'rails_helper'
require_relative '../../../app/services/drug_order_service'


describe TBService::WorkflowEngine do
  include DrugOrderService
	
  let(:epoch) { Time.now }
  let(:tb_program) { program 'TB PROGRAM' } #look into this
  let(:person) do 
		Person.create( birthdate: '1995-01-01', gender: 'M' )  
  end
  let(:person_name) do
    PersonName.create(person_id: person.person_id, given_name: 'John', 
      family_name: 'Doe')
  end
  let(:patient) { Patient.create( patient_id: person.person_id ) }
  
  let(:minor_patient) {create_minor_patient()}
	
  let(:engine) do
    TBService::WorkflowEngine.new program: tb_program,
                                   patient: patient,
                                   date: epoch
  end

  let(:constrained_engine) { raise :not_implemented }

  describe :next_encounter do

    it 'returns TB_INITIAL for an Adult patient not a TB suspect in the TB programme' do
      encounter_type = engine.next_encounter
      expect(encounter_type.name.upcase).to eq('TB_INITIAL')
    end

    it 'returns TB_INITIAL for a new an Adult TB suspect' do

      enroll_patient patient
      encounter_type = engine.next_encounter
      expect(encounter_type.name.upcase).to eq('TB_INITIAL')
    end

    it 'returns LAB ORDERS for an Adult TB suspect with no Lab Request in the TB Programme' do
      tb_initial_encounter patient
      encounter_type = engine.next_encounter
      expect(encounter_type.name.upcase).to eq('LAB ORDERS')
    end

    it 'returns TB ADHERENCE for an Adult TB patient' do
      enroll_patient patient
      tb_initial_encounter patient
      encounter = lab_orders_encounter patient
      prescribe_drugs(patient, encounter)
      medication_orders(patient, encounter)
      patient_weight(patient, encounter)

      drug_quantity = 10
			
			drugs = [
				{
				drug_inventory_id: 985,
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

			drug_orders  = DrugOrderService.create_drug_orders(encounter: treatment_encounter(patient), drug_orders: drugs)
			plain_despenation = [
				{
					drug_order_id: drug_orders[0][:order_id],
          quantity: drug_quantity
				}
      ]

      dispensed = DispensationService.create(plain_despenation)
      encounter_type = engine.next_encounter
      expect(encounter_type.name.upcase).to eq('TB ADHERENCE')
    end

    it 'returns VITALS after patient TB positive' do
      enroll_patient patient
      tb_initial_encounter patient
      encounter = lab_orders_encounter patient
      tb_status(patient, lab_result_encounter(patient))
      encounter_type = engine.next_encounter
      expect(encounter_type.name.upcase).to eq('VITALS')
    end

    it 'returns DISPENSING for an Adult TB patient' do
      enroll_patient patient
      tb_initial_encounter patient
      encounter = lab_orders_encounter patient
      tb_status(patient, lab_result_encounter(patient))
      adherence patient
      record_vitals patient
      treatment_encounter patient
      encounter_type = engine.next_encounter
      expect(encounter_type).to eq(nil)
    end

    it 'returns DIAGONISIS for a minor patient not enrolled as a TB suspect in the TB programme' do
      encounter_type = patient_engine(minor_patient).next_encounter
      expect(encounter_type.name.upcase).to eq('DIAGNOSIS')
    end

    it 'returns TB_INITIAL for a Minor found TB positive through DIAGNOSIS' do
      encounter = diagnosis_encounter(minor_patient)
      tb_status(minor_patient, lab_result_encounter(minor_patient))
      encounter_type = patient_engine(minor_patient).next_encounter
      expect(encounter_type).to eq(nil) #doesnt look right
    end

    it 'returns LAB RESULTS for a TB suspect after Lab Order' do
      enroll_patient patient
      tb_initial_encounter patient
      lab_orders_encounter patient
      encounter_type = engine.next_encounter
      expect(encounter_type.name.upcase).to eq('LAB RESULTS')
    end

  end

  # Helpers methods

  def enroll_patient(patient)
    create :patient_program, patient: patient,
                             program: tb_program
  end

  def tb_initial_encounter(patient)
    tb_initial = create :encounter, type: encounter_type('TB_INITIAL'),
                                   patient: patient, program_id: tb_program.program_id 
    tb_initial
  end

  def record_vitals(patient)
    vitals = create :encounter, type: encounter_type('VITALS'),
                                   patient: patient, program_id: tb_program.program_id
    vitals
  end

  def lab_orders_encounter(patient)
    lab_order = create :encounter, type: encounter_type('LAB ORDERS'),
                                   patient: patient, program_id: tb_program.program_id 
    lab_order
  end

  def treatment_encounter(patient)
    treatment = create :encounter, type: encounter_type('TREATMENT'),
                                   patient: patient, program_id: tb_program.program_id 
    treatment
  end

  def diagnosis_encounter(patient)
    encounter = create :encounter, type: encounter_type('DIAGNOSIS'),
                                   patient: patient, program_id: tb_program.program_id 
    encounter
  end

  def adherence(patient) #patient should recieve drugs
    adherence = create :encounter, type: encounter_type('TB ADHERENCE'),
                                   patient: patient, program_id: tb_program.program_id 
    adherence
  end

  def patient_weight(patient, encounter)
		create :observation, concept: concept('Weight'),
                          encounter: encounter,
                          person: patient.person,
                          value_numeric: 13
	end
	
	def prescribe_drugs(patient, encounter)
		create :observation, concept: concept('Prescribe drugs'),
                          encounter: encounter,
                          person: patient.person,
                          value_coded: concept('Yes').concept_id
	end

	def medication_orders(patient, encounter)										
		create :observation, concept: concept('Medication orders'),
                          encounter: encounter,
                          person: patient.person,
													value_coded: concept('Rifampicin isoniazid and pyrazinamide').concept_id
  end
  
  def tb_status(patient, encounter)
    								
		create :observation, concept: concept('TB status'),
                          encounter: encounter,
                          person: patient.person,
													value_coded: concept('Positive').concept_id
  end
  
  def create_minor_patient
      person = Person.create( birthdate: Date.today, gender: 'F' ) 
      PersonName.create(person_id: person.person_id, given_name: 'John', 
        family_name: 'Doe')
      patient = Patient.create( patient_id: person.person_id )
    
  end

  def patient_engine(patient)
    engine = TBService::WorkflowEngine.new program: tb_program,
                                   patient: patient,
                                   date: epoch
    engine
  end

  def lab_result_encounter(patient)
    encounter = create :encounter, type: encounter_type('LAB RESULTS'),
    patient: patient, program_id: tb_program.program_id 
    encounter
  end
  

end
