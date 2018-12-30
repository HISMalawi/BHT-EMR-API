# frozen_string_literal: true

class PatientService
  include ModelUtils

  def find_by_identifier(identifier, identifier_type: nil)
    identifier_type ||= IdentifierType.find_by('National id')

    Patient.joins(:patient_identifiers).where(
      'patient_identifier.identifier_type = ? AND patient_identifier.identifier = ?',
      identifier_type.patient_identifier_type_id, identifier
    ).first
  end

  def find_patient_median_weight_and_height(patient)
    median_weight_height(patient.age_in_months, patient.person.gender)
  end

  def median_weight_height(age_in_months, gender)
    gender = (gender == 'M' ? '0' : '1')
    values = WeightHeightForAge.where(['age_in_months = ? and sex = ?', age_in_months, gender]).first
    [values.median_weight, values.median_height] if values
  end

  def drugs_orders(patient, date)
    DrugOrder.joins(:order).where(
      'orders.start_date <= ? AND patient_id = ?',
      TimeUtils.day_bounds(date)[1], patient.patient_id
    ).order('orders.start_date DESC')
  end

  def assign_patient_filing_number(patient, filing_number = nil)
    archived_identifier = nil

    if filing_number
      archived_identifier = archive_patient_by_filing_number(filing_number)
    else
      filing_number ||= find_available_filing_number 'Filing number'
    end

    new_identifier = restore_patient(patient, filing_number)
    return nil unless new_identifier

    { new_identifier: new_identifier, archived_identifier: archived_identifier }
  end

  private

  # Find patients that have a (non-archived) filing number that are eligible
  # for archiving.
  #
  # Search order is as follows:
  #   1. Patients with outcome 'Patient died'
  #   2. Patients with outcome 'Patient transferred out'
  #   3. Patients with outcome 'Treatment stopped'
  #   4. Patients with outcome 'Defaulted'
  # def find_archive_candidates
  #   identifier_type_id = patient_identifier_type('Filing number').id
  #   filing_number_prefixes = global_property('filing.number.prefix')&.property_value || 'FN101,FN102'
  #   identifier = filing_number_prefixes.split(',')[0].strip

  #   ['Patient died', 'Patient transferred out', 'Treatment stopped', 'Defaulted'].each do |outcome|
  #     candidates = find_patients_by_outcome_and_identifier outcome: outcome,
  #                                                          identifier_type_id: identifier_type_id,
  #                                                          identifier: "#{identifier}%"
  #     return candidates unless candidates.empty?
  #   end

  #   []
  # end

  # # Retrieves patients with a given outcome and identifier.
  # #
  # # See: find_archive_candidates
  # def find_patients_by_outcome_and_identifier(outcome:, identifier_type_id:,
  #                                             identifier:, date: Date.today,
  #                                             pagination: [0, 10])
  #   offset, limit = pagination

  #   identifiers = PatientIdentifier.where()

  #   while identifiers.size < limit
  #     PatientIdentifier.where
  #   end


  #   Patient.joins(:patient_identifiers).where(
  #     'patient_identifier.identifier like ?
  #      AND patient_identifier.identifier_type = ?
  #      AND patient_outcome(patient.patient_id, ?) = ?',
  #     identifier, identifier_type_id, date, outcome
  #   ).offset(offset).limit(limit)
  # end

  # Search for an available filing number
  #
  # Source: NART#app/models/patient_identifiers and NART#lib/patient_service
  def find_available_filing_number(type)
    filing_number_type = patient_identifier_type(type)

    filing_number_prefix = global_property('filing.number.prefix')&.property_value
    filing_number_prefix ||= 'FN101,FN102'

    prefix = filing_number_prefix.split(',')[0][0..4] if type.match?(/(Filing)/i)
    prefix = filing_number_prefix.split(',')[1][0..4] if type.match?(/Archived/i)

    possible_identifiers_limit = global_property('possible.filing.numbers')&.property_value&.to_i
    possible_identifiers_limit ||= 99_999

    possible_identifiers = 1.upto(possible_identifiers_limit).collect do |num|
      "#{prefix}#{num.to_s.rjust(5, '0')}"
    end

    used_identifiers = PatientIdentifier.where(type: filing_number_type).map(&:identifier)
    (possible_identifiers - used_identifiers.compact.uniq).min
  end

  # Archives patient with given filing number
  def archive_patient_by_filing_number(filing_number)
    identifier = PatientIdentifier.find_by type: patient_identifier_type('Filing number'),
                                           identifier: filing_number
    return unless identifier

    identifier.void('Filing number re-assigned to another patient')

    PatientIdentifier.create type: patient_identifier_type('Archived Filing Number'),
                             identifier: find_available_filing_number('Archived filing number'),
                             patient: identifier.patient,
                             location_id: Location.current.location_id
  end

  # Restores a patient onto the filing system by assigning the patient a new filing number
  #
  # Sort of the reversal of `archive_patient_by_filing_number`
  #
  # Source: This method was originally NART#lib/patient_service#next_filing_number_to
  #         be_archived.
  def restore_patient(patient, filing_number)
    ActiveRecord::Base.transaction do
      active_filing_number_identifier_type = patient_identifier_type('Filing Number')
      dormant_filing_number_identifier_type = patient_identifier_type('Archived filing number')

      filing_number_limit = global_property('filing.number.limit')&.property_value&.to_i
      filing_number_limit ||= 10_000

      return nil if filing_number[5..-1].to_i > filing_number_limit

      # Void current dormant filing number
      existing_dormant_filing_numbers = PatientIdentifier.where(
        patient: patient, type: dormant_filing_number_identifier_type
      )

      existing_dormant_filing_numbers.each do |identifier|
        identifier.void("Given active filing number: #{filing_number}")
      end

      PatientIdentifier.create patient: patient,
                               type: active_filing_number_identifier_type,
                               identifier: filing_number,
                               location_id: Location.current.location_id
    end
  end
end
