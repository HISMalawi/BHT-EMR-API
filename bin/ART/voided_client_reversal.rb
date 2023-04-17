# frozen_string_literal: true

# define a method that fetches a patient given their identifier
def voided_patient(identifier:)
  identifier = PatientIdentifier.unscoped.find_by(identifier: identifier)
  patient = Patient.unscoped.find(identifier.patient_id)
  return patient if patient.present?

  raise "Patient with identifier #{identifier} not found"
end

def unvoid_patient(patient:)
    patient.voided = 0
    patient.voided_by = nil
    patient.date_voided = nil
    patient.void_reason = nil

    patient.save!
end

def unvoid_person(patient:)
    person = Person.unscoped.find(patient.patient_id)
    person.voided = 0
    person.voided_by = nil
    person.date_voided = nil
    person.void_reason = nil
    patient.save!
end

def unvoid_person_name(patient:)
    names = PersonName.unscoped.where(person_id: patient.patient_id, date_voided: patient.date_voided)
    names.each do |name|
        name.voided = 0
        name.voided_by = nil
        name.date_voided = nil
        name.void_reason = nil
        name.save!
    end
end
