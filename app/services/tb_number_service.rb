require 'securerandom'

class TbNumberService
  include ModelUtils

  TB_NUMBER_IDENTIFIER_NAME = 'District TB Number'
  IPT_NUMBER_IDENTIFIER_NAME = 'District IPT Number'
  FACILITY_CODE_GLOBAL_PROPERTY_NAME = 'site_prefix'

  def assign_tb_number(patient_id, date)
    PatientIdentifier.create(
      identifier: generate_tb_number(date),
      type: patient_identifier_type(TB_NUMBER_IDENTIFIER_NAME),
      patient_id: patient_id,
      location_id: Location.current.location_id,
      date_created: date
    )
  end

  def assign_ipt_number(patient_id, date)
    PatientIdentifier.create(
      identifier: generate_ipt_number(date),
      type: patient_identifier_type(IPT_NUMBER_IDENTIFIER_NAME),
      patient_id: patient_id,
      location_id: Location.current.location_id,
      date_created: date
    )
  end

  def get_tb_number(patient_id)
    patient_identifier = PatientIdentifier.where(
      type: patient_identifier_type(TB_NUMBER_IDENTIFIER_NAME),
      patient_id: patient_id
    )
    .order(date_created: :desc)
    .first
  end

  def get_ipt_number(patient_id)
    patient_identifier = PatientIdentifier.where(
      type: patient_identifier_type(IPT_NUMBER_IDENTIFIER_NAME),
      patient_id: patient_id
    )
    .order(date_created: :desc)
    .first
  end

  private
  def generate_tb_number(date)
    id = retrieve_recent_id_number(TB_NUMBER_IDENTIFIER_NAME) + 1
    "#{get_facility_code}/TB/#{id}/#{date.year}"
  end

  def generate_ipt_number(date)
    id = retrieve_recent_id_number(IPT_NUMBER_IDENTIFIER_NAME) + 1
    "#{get_facility_code}/IPT/#{id}/#{date.year}"
  end

  def retrieve_recent_id_number(id_type)
    patient_identifer = PatientIdentifier.where(
      type: patient_identifier_type(id_type)
    )
    .order(date_created: :desc)
    .first

    begin
      patient_identifer.patient_identifier_id
    rescue
      0
    end

  end

  def get_facility_code
    global_property(FACILITY_CODE_GLOBAL_PROPERTY_NAME)&.property_value
  end
end