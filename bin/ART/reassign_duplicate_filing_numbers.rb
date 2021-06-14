# frozen_string_literal: true

require 'csv'

FILING_NUMBER_TYPE = PatientIdentifierType.find_by_name!('Filing number')
ARCHIVED_FILING_NUMBER_TYPE = PatientIdentifierType.find_by_name!('Archived filing number')

##
# Finds all patients with a given filing number
def find_patients_by_filing_number(filing_number, filing_number_type)
  identifiers = PatientIdentifier.where(type: filing_number_type, identifier: filing_number)
  Patient.joins(:patient_identifiers).merge(identifiers)
end

def filing_number_service()
  FilingNumberService.new
end

##
# Blesses patient with an archived filing number
def archive_patient(patient)
  Rails.logger.debug("Archiving patient ##{patient.patient_id}")
  new_filing_number = filing_number_service.find_available_filing_number(ARCHIVED_FILING_NUMBER_TYPE.name)
  raise 'Out of Archived filing numbers' unless new_filing_number

  PatientIdentifier.create!(
    type: ARCHIVED_FILING_NUMBER_TYPE,
    identifier: new_filing_number,
    patient: patient,
    location_id: Location.current.location_id
  )

  new_filing_number
end

##
# Void all of all a patient's filing numbers of a given type
def void_patient_filing_numbers(patient, type)
  Rails.logger.debug("Voiding patient ##{patient.patient_id} '#{type.name}' identifiers")
  PatientIdentifier.where(patient: patient, type: type)
                   .each { |identifier| identifier.void('Duplicate filing number') }
end

def process_duplicate_archived_filing_numbers
  Rails.logger.info('Processing duplicate archived filing numbers...')
  duplicates = PatientIdentifierService.find_duplicates(ARCHIVED_FILING_NUMBER_TYPE)

  duplicates.each_with_object([]) do |duplicate, reassigned_patients|
    find_patients_by_filing_number(duplicate.fetch(:identifier), ARCHIVED_FILING_NUMBER_TYPE).each do |patient|
      void_patient_filing_numbers(patient, ARCHIVED_FILING_NUMBER_TYPE)
      new_filing_number = archive_patient(patient)

      reassigned_patients << OpenStruct.new(patient: patient,
                                            old_filing_number: duplicate.fetch(:identifier),
                                            new_filing_number: new_filing_number)
    end
  end
end

def process_duplicate_filing_numbers
  Rails.logger.info('Processing duplicate filing numbers...')
  duplicates = PatientIdentifierService.find_duplicates(FILING_NUMBER_TYPE)

  duplicates.each_with_object([]) do |duplicate, untracked_patients|
    find_patients_by_filing_number(duplicate.fetch(:identifier), FILING_NUMBER_TYPE).each do |patient|
      void_patient_filing_numbers(patient, FILING_NUMBER_TYPE)

      untracked_patients << OpenStruct.new(patient: patient, old_filing_number: duplicate.fetch(:identifier))
    end
  end
end

##
# Returns patient's NHID and ARV Number
def find_patient_identifiers(patient)
  ['National ID', 'ARV Number'].map do |identifier_type_name|
    type = PatientIdentifierType.where(name: identifier_type_name)
    identifier = PatientIdentifier.find_by(patient: patient, type: type)

    identifier&.identifier
  end
end

def save_filed_patients(filename, patient_filing_details)
  CSV.open(filename, 'w') do |csv|
    Rails.logger.info("Saving filing details to: #{filename}")
    csv << ['Patient ID', 'NHID', 'ARV #', 'Old Filing Number', 'New Filing Number']
    patient_filing_details.each do |filing_detail|
      nhid, arv_number = find_patient_identifiers(filing_detail.patient)

      csv << [filing_detail.patient.patient_id,
              nhid,
              arv_number,
              filing_detail.old_filing_number,
              filing_detail.new_filing_number]
    end
  end
end

Rails.logger = Logger.new($stdout)
ActiveRecord::Base.logger = Rails.logger
ActiveRecord::Base.logger.level = :debug

print 'Enter your username> '
username = gets.strip

User.current = User.find_by_username(username)
location_id = GlobalProperty.find_by_property!('current_health_center_id').property_value.to_i
Location.current = Location.find(location_id)

unless User.current
  warn("Error: user '#{username}' does not exist")
  exit(1)
end

ActiveRecord::Base.transaction do
  untracked_patients = process_duplicate_filing_numbers
  archived_patients = process_duplicate_archived_filing_numbers
  all_patients = untracked_patients + archived_patients

  save_filed_patients('log/filing-number-deduplications.csv', all_patients)
  Rails.logger.info("Successfully processed #{all_patients.size}")
end
