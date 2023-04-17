# frozen_string_literal: true

# define a method that fetches a patient given their identifier
def voided_patient(identifier:)
  identifier = PatientIdentifier.unscoped.find_by(identifier: identifier, voided: true)
  raise "Identifier #{identifier} that is voided was not found" if identifier.blank?

  patient = Patient.unscoped.find(identifier.patient_id)
  return patient if patient.present?

  raise "Patient with identifier #{identifier} not found"
end

def unvoid_patient(patient:)
  pat = Patient.unscoped.find_by(patient_id: patient['patient_id'])
  pat.update!(voided: 0, voided_by: nil, date_voided: nil, void_reason: nil)
end

def unvoid_person(patient:)
  person = Person.unscoped.find_by(person_id: patient['patient_id'])
  person.update!(voided: 0, voided_by: nil, date_voided: nil, void_reason: nil)
end

def unvoid_person_name(patient:)
  names = PersonName.unscoped.where(person_id: patient['patient_id'], date_voided: patient['date_voided'])
  names.each do |name|
    name.update!(voided: 0, voided_by: nil, date_voided: nil, void_reason: nil)
  end
end

def unvoid_patient_identifier(patient:)
  identifiers = PatientIdentifier.unscoped.where(patient_id: patient['patient_id'], date_voided: patient['date_voided'])
  identifiers.each do |identifier|
    identifier.update!(voided: 0, voided_by: nil, date_voided: nil, void_reason: nil)
  end
end

def unvoid_person_attributes(patient:)
  attributes = PersonAttribute.unscoped.where(person_id: patient['patient_id'], date_voided: patient['date_voided'])
  attributes.each do |attribute|
    attribute.update!(voided: 0, voided_by: nil, date_voided: nil, void_reason: nil)
  end
end

def unvoid_person_addressess(patient:)
  addresses = PersonAddress.unscoped.where(person_id: patient['patient_id'], date_voided: patient['date_voided'])
  addresses.each do |address|
    address.update!(voided: 0, voided_by: nil, date_voided: nil, void_reason: nil)
  end
end

def unvoid_relationship(patient:)
  relationships = Relationship.unscoped.where(person_a: patient['patient_id'], date_voided: patient['date_voided'])
  relationships.each do |relationship|
    relationship.update!(voided: 0, voided_by: nil, date_voided: nil, void_reason: nil)
  end
end

def unvoid_patient_program(patient:)
  programs = PatientProgram.unscoped.where(patient_id: patient['patient_id'], date_voided: patient['date_voided'])
  programs.each do |program|
    program.update!(voided: 0, voided_by: nil, date_voided: nil, void_reason: nil)
  end
end

def unvoid_patient_state(patient:)
  patient_programs = PatientProgram.where(patient_id: patient['patient_id']).collect(&:patient_program_id)
  states = PatientState.unscoped.where(patient_program_id: patient_programs, date_voided: patient['date_voided'])
  states.each do |state|
    state.update!(voided: 0, voided_by: nil, date_voided: nil, void_reason: nil)
  end
end

def unvoid_encounters(patient:)
  encounters = Encounter.unscoped.where(patient_id: patient['patient_id'], date_voided: patient['date_voided'])
  encounters.each do |encounter|
    encounter.update!(voided: 0, voided_by: nil, date_voided: nil, void_reason: nil)
  end
end

def unvoid_orders(patient:)
  orders = Order.unscoped.where(patient_id: patient['patient_id'], date_voided: patient['date_voided'])
  orders.each do |order|
    order.update!(voided: 0, voided_by: nil, date_voided: nil, void_reason: nil)
  end
end

def unvoid_obs(patient:)
  obs = Observation.unscoped.where(person_id: patient['patient_id'], date_voided: patient['date_voided'])
  obs.each do |ob|
    ob.update!(voided: 0, voided_by: nil, date_voided: nil, void_reason: nil)
  end
end

def process_person(patient:)
  unvoid_person_name(patient: patient)
  unvoid_person_attributes(patient: patient)
  unvoid_person_addressess(patient: patient)
  unvoid_relationship(patient: patient)
end

def process_patient(patient:)
  unvoid_patient_identifier(patient: patient)
  unvoid_patient_program(patient: patient)
  unvoid_patient_state(patient: patient)
end

def process_encounters(patient:)
  unvoid_encounters(patient: patient)
  unvoid_orders(patient: patient)
  unvoid_obs(patient: patient)
end

def process_request(identifier:)
  patient = voided_patient(identifier: identifier).attributes
  Rails.logger.info "Processing patient with identifier #{identifier}"
  ActiveRecord::Base.transaction do
    unvoid_person(patient: patient)
    unvoid_patient(patient: patient)
    process_person(patient: patient)
    process_encounters(patient: patient)
    process_patient(patient: patient)
  end
end

Rails.logger = Logger.new($stdout)
ActiveRecord::Base.logger = Rails.logger
ActiveRecord::Base.logger.level = :debug
User.current = User.first

print 'Enter your patient identifier> '
identifier = gets.strip

process_request(identifier: identifier)
