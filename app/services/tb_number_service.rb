include ModelUtils

class TBNumberService
  class DuplicateIdentifierError < StandardError; end

  NORMAL_TYPE = 'District TB Number'
  IPT_TYPE = 'District IPT Number'

  def self.assign_tb_number (patient_id, date, number)
    identifier = generate_tb_number(patient_id, date, number)
    raise DuplicateIdentifierError if number_exists?(number: identifier)

    PatientIdentifier.create(
      identifier: identifier,
      type: number_type(patient_id: patient_id),
      patient_id: patient_id,
      location_id: Location.current.location_id,
      date_created: date
    )
  end

  def self.get_patient_tb_number (patient_id:)
    PatientIdentifier.where(type: patient_identifier_type(NORMAL_TYPE),
                            patient_id: patient_id)\
                     .or(PatientIdentifier.where(type: patient_identifier_type(IPT_TYPE), patient_id: patient_id))\
                     .order(date_created: :desc)
                     .first
  end

  def self.generate_tb_patient_id(patient_id)
    patient_identifier = get_patient_tb_number(patient_id: patient_id)

    return if patient_identifier.nil?

    identifier_name = PatientIdentifierType.find_by(patient_identifier_type_id: patient_identifier.identifier_type).name
    first_name = PersonName.find_by(person_id: patient_id).given_name
    last_name = PersonName.find_by(person_id: patient_id).family_name
    name = "#{first_name} #{last_name}"
    label = ZebraPrinter::StandardLabel.new
    label.draw_text(name, 40, 10, 0, 2, 2, 2, false)
    label.draw_text(identifier_name, 40, 60, 0, 2, 2, 2, false)
    label.draw_text(patient_identifier.identifier, 40, 120, 0, 2, 2, 2, false)
    label.draw_barcode(50, 180, 0, 1, 5, 15, 120, false, patient_identifier.identifier)
    label.print(1)
  end

  private

  def self.generate_tb_number (patient_id, date, number)
    is_ipt_patient = ipt_eligible?(patient_id: patient_id)
    category = is_ipt_patient ? 'IPT' : 'TB'

    "#{facility_code}/#{category}/#{number}/#{date.year}"
  end

  def self.number_exists?(number:)
    PatientIdentifier.where(identifier: number)\
                     .exists?
  end

  def self.ipt_eligible? (patient_id:)
    regimen_engine.is_eligible_for_ipt?(person: Person.find(patient_id))
  end

  def self.number_type (patient_id:)
    type = ipt_eligible?(patient_id: patient_id) ? IPT_TYPE : NORMAL_TYPE
    patient_identifier_type(type)
  end

  def self.regimen_engine
    TbService::RegimenEngine.new(program: program('TB Program'))
  end

  def self.facility_code
    global_property('tb_site_prefix')&.property_value
  end
end