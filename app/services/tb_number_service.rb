include ModelUtils

class TBNumberService
  class TbNumberAlreadyExistsException < StandardError; end

  NORMAL_TYPE = 'District TB Number'
  IPT_TYPE = 'District IPT Number'

  def self.assign_tb_number (patient_id, date, number = nil)
    suggested = generate_tb_number(patient_id, date, number)
    raise TbNumberAlreadyExistsException if number && number_exists?(number: suggested)

    PatientIdentifier.create(
      identifier: suggested,
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

  private

  def self.generate_tb_number (patient_id, date, number = nil)
    is_ipt_patient = ipt_eligible?(patient_id: patient_id)
    category = is_ipt_patient ? 'IPT' : 'TB'

    next_number = number
    next_number = next_available_number(patient_id: patient_id) if number == nil

    "#{facility_code}/#{category}/#{next_number}/#{date.year}"
  end

  def self.number_exists?(number:)
    PatientIdentifier.where(identifier: number)\
                     .exists?
  end

  def self.ipt_eligible? (patient_id:)
    regimen_engine.is_eligible_for_ipt?(person: Person.find(patient_id))
  end

  def self.next_available_number (patient_id:)
    number = PatientIdentifier.where(type: number_type(patient_id: patient_id))\
                              .order(date_created: :desc)\
                              .first

    return 1 if number.blank?
    number.patient_identifier_id.next
  end

  def self.number_type (patient_id:)
    type = ipt_eligible?(patient_id: patient_id) ? IPT_TYPE : NORMAL_TYPE
    patient_identifier_type(type)
  end

  def self.regimen_engine
    TBService::RegimenEngine.new(program: program('TB Program'))
  end

  def self.facility_code
    global_property('site_prefix')&.property_value
  end
end