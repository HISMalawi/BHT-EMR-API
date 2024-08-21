# frozen_string_literal: true

include ModelUtils

class TbNumberService
  class DuplicateIdentifierError < StandardError; end
  NORMAL_TYPE = 'District TB Number'
  IPT_TYPE = 'District IPT Number'
  MDR_TYPE = 'MDR-TB Program Identifier'
  NATIONAL_ID = 'Malawi National ID'

  def self.assign_national_id(patient_id, _date, identifier)
    national_id_type = patient_identifier_type(NATIONAL_ID).patient_identifier_type_id

    raise DuplicateIdentifierError if number_exists?(number: identifier, identifier_type: national_id_type)

    PatientIdentifier.create(
      identifier:,
      identifier_type: national_id_type,
      patient_id:,
      location_id: Location.current.location_id
    )
  end

  def self.update_national_id(patient_id, _date, identifier)
    national_id_type = patient_identifier_type(NATIONAL_ID).patient_identifier_type_id
    raise DuplicateIdentifierError if number_exists?(number: identifier, identifier_type: national_id_type)

    curr_identifier = PatientIdentifier.find_by(patient_id:, identifier_type: national_id_type)
    curr_identifier.identifier = identifier
    curr_identifier.save
  end

  def self.assign_tb_number(patient_id, date, number, type)
    identifier = generate_tb_number(patient_id, date, number, type)
    raise DuplicateIdentifierError if number_exists?(number: identifier, identifier_type: nil)

    record = PatientIdentifier.create(
      identifier:,
      identifier_type: type,
      patient_id:,
      location_id: Location.current.location_id
    )
    # This is a workaround to save date created with date variable. When done in the method above
    # it gets overwritten with current date..
    record.date_created = date
    record.save
    record
  end

  def self.mw_national_identifier(patient_id)
    PatientIdentifier.where(identifier_type: patient_identifier_type(NATIONAL_ID),
                            patient_id:)
                     .order(date_created: :desc)
                     .first
  end

  def self.get_patient_tb_number(patient_id, id_type)
    PatientIdentifier.where(identifier_type: id_type.to_i,
                            patient_id:)\
                     .or(PatientIdentifier.where(type: patient_identifier_type(IPT_TYPE), patient_id:))\
                     .order(date_created: :desc)
                     .first
  end

  def self.get_current_patient_identifier(patient_id:)
    valid_identifiers_types = [
      patient_identifier_type(NORMAL_TYPE).patient_identifier_type_id,
      patient_identifier_type(IPT_TYPE).patient_identifier_type_id,
      patient_identifier_type(MDR_TYPE).patient_identifier_type_id
    ]
    PatientIdentifier.where(type: valid_identifiers_types, patient_id:)\
                     .order(date_created: :desc)
                     .first
  end

  def self.generate_tb_patient_id(patient_id)
    patient_identifier = get_current_patient_identifier(patient_id:)

    return if patient_identifier.nil?

    identifier_name = PatientIdentifierType.find_by(patient_identifier_type_id: patient_identifier.identifier_type).name
    first_name = PersonName.find_by(person_id: patient_id).given_name
    last_name = PersonName.find_by(person_id: patient_id).family_name
    name = "#{first_name} #{last_name}"
    label = ZebraPrinter::Lib::StandardLabel.new
    label.draw_text(name, 40, 10, 0, 2, 2, 2, false)
    label.draw_text(identifier_name, 40, 60, 0, 2, 2, 2, false)
    label.draw_text(patient_identifier.identifier, 40, 120, 0, 2, 2, 2, false)
    label.draw_barcode(50, 180, 0, 1, 5, 15, 120, false, patient_identifier.identifier)
    label.print(1)
  end

  def self.generate_tb_number(_patient_id, date, number, type)
    identifier_type = PatientIdentifierType.find(type)

    category = case identifier_type.name
               when 'District IPT Number'
                 'IPT'
               when 'District TB Number'
                 'TB'
               when 'MDR-TB Program Identifier'
                 'MDR'
               else
                 'TB'
               end

    "#{facility_code}/#{category}/#{number}/#{date&.to_date&.year}"
  end

  def self.number_exists?(number:, identifier_type:)
    query = PatientIdentifier.where(identifier: number)
    query = query.where(type: identifier_type) unless identifier_type.nil?
    query.exists?
  end

  def self.ipt_eligible?(patient_id:)
    regimen_engine.is_eligible_for_ipt?(person: Person.find(patient_id))
  end

  def self.number_type(patient_id:)
    type = ipt_eligible?(patient_id:) ? IPT_TYPE : NORMAL_TYPE
    patient_identifier_type(type)
  end

  def self.regimen_engine
    TbService::RegimenEngine.new(program: program('TB Program'))
  end

  def self.facility_code
    global_property('tb_site_prefix')&.property_value
  end
end
