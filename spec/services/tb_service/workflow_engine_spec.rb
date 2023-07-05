# frozen_string_literal: true

require 'rails_helper'
require_relative '../../../app/services/drug_order_service'


describe TbService::WorkflowEngine do
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
    TbService::WorkflowEngine.new program: tb_program,
                                   patient: patient,
                                   date: epoch
  end

  let(:drug_quantity) {10}

  let(:constrained_engine) { raise :not_implemented }

  describe :next_encounter do

    it 'returns TB_INITIAL for a patient not a TB suspect in the TB programme' do
      encounter_type = engine.next_encounter
      expect(encounter_type.name.upcase).to eq('TB_INITIAL')
    end

    it 'returns TB_INITIAL for a new a TB suspect' do

      enroll_patient patient
      encounter_type = engine.next_encounter
      expect(encounter_type.name.upcase).to eq('TB_INITIAL')
    end

    it 'returns VITALS after patient TB positive' do
      enroll_patient patient
      tb_initial_encounter(patient, Time.now - 2.hour)
      encounter = lab_orders_encounter(patient, Time.now - 2.hour)
      tb_status(patient, lab_result_encounter(patient, Time.now + 1.hour), "Positive")
      tb_reception(patient, Time.now + 1.hour)
      tb_registration(patient, Time.now + 1.hour)
      encounter_type = engine.next_encounter
      expect(encounter_type.name.upcase).to eq('VITALS')
    end

    it 'returns DISPENSING for an Adult TB patient' do
      enroll_patient patient
      tb_initial_encounter(patient, Time.now - 2.hour)
      encounter = lab_orders_encounter(patient, Time.now - 2.hour)
      tb_status(patient, lab_result_encounter(patient, Time.now + 1.hour), "Positive")
      tb_reception(patient, Time.now + 1.hour)
      tb_registration(patient, Time.now + 1.hour)
      adherence(patient, Time.now)
      record_vitals(patient, Time.now)
      treatment_encounter(patient, Time.now)
      encounter_type = engine.next_encounter
      expect(encounter_type.name.upcase).to eq('DISPENSING')
    end

    it 'returns LAB RESULTS for a TB suspect after 1 hour prior a Lab Order' do
      enroll_patient patient
      test_procedure_type(patient, tb_initial_encounter(patient, Time.now - 2.hour), "Laboratory examinations", Time.now - 2.hour)
      lab_orders_encounter(patient, Time.now - 2.hour)
      encounter_type = engine.next_encounter
      expect(encounter_type.name.upcase).to eq('LAB RESULTS')
    end

    it 'returns APPOINTMENT for a TB patient' do
      skip('Add missing drug #985')
      # enroll_patient patient
      # tb_initial_encounter(patient, Time.now - 2.hour)
      # dispensing_encounter(patient, Time.now - 2.hour)
      # dispensation()
      # encounter_type = engine.next_encounter
      # expect(encounter_type.name.upcase).to eq('APPOINTMENT')
    end

    it 'returns TB TREATMENT after recording TB Vitals' do
      enroll_patient patient
      tb_initial_encounter(patient, Time.now - 2.hour)
      encounter = lab_orders_encounter(patient, Time.now - 2.hour)
      tb_status(patient, lab_result_encounter(patient, Time.now), "Positive")
      tb_reception(patient, Time.now)
      tb_registration(patient, Time.now + 1.hour)
      record_vitals(patient, Time.now)
      encounter_type = engine.next_encounter
      expect(encounter_type.name.upcase).to eq('TB TREATMENT')
    end

    #After patient transferred out it will go dashboard
    it 'returns nil for a patient transferred out after dispensation' do
      skip('Add missing drug #985')
      # enroll_patient patient
      # initial_encounter = tb_initial_encounter(patient, Time.now - 2.hour)
      # dispensing_encounter(patient, Time.now - 2.hour)
      # dispensation()
      # transfer_out_observation(patient, initial_encounter, 'YES')
      # encounter_type = engine.next_encounter
      # expect(encounter_type).to eq(nil)
    end

    it 'returns LAB ORDER after test procedure type LAB ORDER' do
      enroll_patient patient
      encounter = tb_initial_encounter(patient, Time.now - 20.minutes)
      test_procedure_type(patient, encounter, "Laboratory examinations", Time.now - 20.minutes)
      encounter_type = engine.next_encounter
      expect(encounter_type.name.upcase).to eq('LAB ORDERS')
    end

    #proceed to Diagnosis 10 minutes after TB screening
    it 'returns DIAGNOSIS after procedure type Clinical or XRay or Ultrasound' do
      enroll_patient patient
      encounter = tb_initial_encounter(patient, Time.now - 20.minutes)
      test_procedure_type(patient, encounter, "Ultrasound", Time.now - 20.minutes)
      encounter_type = engine.next_encounter
      expect(encounter_type.name.upcase).to eq('DIAGNOSIS')
    end

    it 'returns TB Adherence for a follow up patient' do
      enroll_patient patient
      appointment_encounter(patient, Time.now - 1.day) #appointment for previous visit
      encounter = tb_initial_encounter(patient, Time.now - 2.day)
      test_procedure_type(patient, tb_initial_encounter(patient, Time.now - 2.day), "Laboratory examinations", Time.now - 2.day)
      lab_orders_encounter(patient, Time.now - 2.day)
      tb_status(patient, lab_result_encounter(patient, Time.now), "Positive")
      tb_reception(patient, Time.now)
      tb_registration(patient, Time.now)
      record_vitals(patient, Time.now)
      treatment_encounter(patient, Time.now)
      dispensing_encounter(patient, Time.now)
      appointment_encounter(patient, Time.now) #Seet appointment for next visit
      encounter_type = engine.next_encounter
      expect(encounter_type.name.upcase).to eq('TB ADHERENCE')
    end

    #this test may fail based on the time difference for a required lab order
    it 'returns LAB ORDERS for a follow up patient' do
      enroll_patient patient
      test_procedure_type(patient, tb_initial_encounter(patient, Time.now - 2.day), "Laboratory examinations", Time.now - 2.day)
      lab_orders_encounter(patient, Time.now - 2.day)
      tb_status(patient, lab_result_encounter(patient, Time.now), "Positive")
      record_vitals(patient, Time.now)
      dispensing_encounter(patient, Time.now - 56.day)
      appointment_encounter(patient, Time.now - 56.day)
      adherence(patient, Time.now)
      encounter_type = engine.next_encounter
      expect(encounter_type.name.upcase).to eq('LAB ORDERS')
    end

  end

  # Helpers methods

  def enroll_patient(patient)
    create :patient_program, patient: patient,
                             program: tb_program
  end

  def tb_initial_encounter(patient, datetime)
    tb_initial = create :encounter, type: encounter_type('TB_INITIAL'),
                                   patient: patient, program_id: tb_program.program_id, encounter_datetime: datetime
    tb_initial
  end

  def record_vitals(patient, datetime)
    vitals = create :encounter, type: encounter_type('VITALS'),
                                   patient: patient, program_id: tb_program.program_id, encounter_datetime: datetime
    vitals
  end

  def lab_orders_encounter(patient, datetime)
    lab_order = create :encounter, type: encounter_type('LAB ORDERS'),
                                   patient: patient, program_id: tb_program.program_id, encounter_datetime: datetime
    lab_order
  end

  def treatment_encounter(patient, datetime)
    treatment = create :encounter, type: encounter_type('TREATMENT'),
                                   patient: patient, program_id: tb_program.program_id, encounter_datetime: datetime
    treatment
  end

  def diagnosis_encounter(patient, datetime)
    encounter = create :encounter, type: encounter_type('DIAGNOSIS'),
                                   patient: patient, program_id: tb_program.program_id, encounter_datetime: datetime
    encounter
  end

  def adherence(patient, datetime) #patient should recieve drugs
    adherence = create :encounter, type: encounter_type('TB ADHERENCE'),
                                   patient: patient, program_id: tb_program.program_id, encounter_datetime: datetime
    adherence
  end

  def patient_weight(patient, encounter)
		create :observation, concept: concept('Weight'),
                          encounter: encounter,
                          person: patient.person,
                          value_numeric: 13
	end

	def medication_orders(patient, encounter)
		create :observation, concept: concept('Medication orders'),
                          encounter: encounter,
                          person: patient.person,
													value_coded: concept('Rifampicin isoniazid and pyrazinamide').concept_id
  end

  def tb_status(patient, encounter, status)

		create :observation, concept: concept('TB status'),
                          encounter: encounter,
                          person: patient.person,
													value_coded: concept(status).concept_id
  end

  def create_minor_patient
      person = Person.create( birthdate: Date.today, gender: 'F' )
      PersonName.create(person_id: person.person_id, given_name: 'John',
        family_name: 'Doe')
      patient = Patient.create( patient_id: person.person_id )

  end

  def patient_engine(patient)
    engine = TbService::WorkflowEngine.new program: tb_program,
                                   patient: patient,
                                   date: epoch
    engine
  end

  def lab_result_encounter(patient, datetime)
    encounter = create :encounter, type: encounter_type('LAB RESULTS'),
    patient: patient, program_id: tb_program.program_id, encounter_datetime: datetime
    encounter
  end

  def appointment_encounter(patient, datetime)
    encounter = create :encounter, type: encounter_type('APPOINTMENT'),
    patient: patient, program_id: tb_program.program_id, encounter_datetime: datetime
    encounter
  end

  def back_data_tb_initial_encounter(patient, datetime)

    tb_initial = create :encounter, type: encounter_type('TB_INITIAL'),
                                   patient: patient, program_id: tb_program.program_id,
                                   encounter_datetime: datetime
    tb_initial
  end

  def tb_reception(patient, datetime)
    encounter = create :encounter, type: encounter_type('TB RECEPTION'),
                                   patient: patient, program_id: tb_program.program_id,
                                   encounter_datetime: datetime
    encounter
  end

  def tb_registration(patient, datetime)
    encounter = create :encounter, type: encounter_type('TB REGISTRATION'),
                                   patient: patient, program_id: tb_program.program_id,
                                   encounter_datetime: datetime
    encounter
  end

  def tb_status_through_diagnosis(patient, encounter, status)

		create :observation, concept: concept('TB status'),
                          encounter: encounter,
                          person: patient.person,
													value_coded: concept(status).concept_id
  end

  def test_procedure_type(patient, encounter, procedure, datetime)
    create :observation, concept: concept('Procedure type'),
                          encounter: encounter,
                          person: patient.person,
                          value_coded: concept(procedure).concept_id,
                          obs_datetime: datetime
  end

  def transfer_out_observation(patient, encounter, answer)

		create :observation, concept: concept('Patient transferred(external facility)'),
                          encounter: encounter,
                          person: patient.person,
													value_coded: concept(answer).concept_id
  end

  def drugs
    [
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
      tb_reception(patient, Time.now)
      tb_registration(patient, Time.now)
      record_vitals(patient, Time.now)
      medication_orders(patient, encounter)
      patient_weight(patient, encounter)

      drug_orders  = DrugOrderService.create_drug_orders(encounter: treatment_encounter(patient, Time.now), drug_orders: drugs())
			plain_despenation = dispense(drug_orders)
      DispensationService.create(tb_program, plain_despenation)
  end

  def dispensing_encounter(patient, datetime)
    encounter = create :encounter, type: encounter_type('DISPENSING'),
    patient: patient, program_id: tb_program.program_id, encounter_datetime: datetime
    encounter
  end


end
