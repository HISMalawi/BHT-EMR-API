# frozen_string_literal: true

# define a method that fetches a patient given their identifier
def voided_patient(identifier:, given_name:, family_name:, gender:, birthdate:)
  patient = ActiveRecord::Base.connection.select_one <<~SQL
    SELECT p.*
    FROM patient_identifier pi
    INNER JOIN patient p ON p.patient_id = pi.patient_id AND p.voided = 1
    INNER JOIN person pe ON pe.person_id = p.patient_id AND pe.voided = 1
    INNER JOIN person_name pn ON pn.person_id = pe.person_id AND pn.voided = 1
    WHERE pi.identifier = '#{identifier}' AND pn.given_name = '#{given_name}'
    AND pn.family_name = '#{family_name}' AND pe.gender = '#{gender}'
    AND pe.birthdate = '#{birthdate}' AND pi.voided = 1
  SQL
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
    encounter.update!(voided: 0, voided_by: nil, date_voided: nil, void_reason: nil) if encounter.program_id.present?
    next if encounter.program_id.present?
    
    # update using raw query to avoid validation errors
    ActiveRecord::Base.connection.execute <<~SQL
      UPDATE encounter SET voided = 0, voided_by = NULL, date_voided = NULL, void_reason = NULL
      WHERE encounter_id = #{encounter['encounter_id']}
    SQL
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

def process_request(identifier:, given_name:, family_name:, gender:, birthdate:)
  patient = voided_patient(identifier: identifier, given_name: given_name, family_name: family_name, gender: gender, birthdate: birthdate)
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
print 'Enter patient first name> '
given_name = gets.strip
print 'Enter patient last name> '
family_name = gets.strip
print 'Enter patient gender (F or M)> '
gender = gets.strip
print 'Enter patient birthdate in the following format(yyyy-mm-dd) i.e 1987-07-15> '
birthdate = gets.strip

process_request(identifier: identifier, given_name: given_name, family_name: family_name, gender: gender, birthdate: birthdate)
