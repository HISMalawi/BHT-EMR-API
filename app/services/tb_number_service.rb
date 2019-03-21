require 'securerandom'

class TbNumberService
  include ModelUtils

  TB_NUMBER_IDENTIFIER_NAME = 'District TB Number'
  FACILITY_CODE_GLOBAL_PROPERTY_NAME = 'site_prefix'

  def assign_tb_number(patient_id)
    PatientIdentifier.create(
      identifier: generate_tb_number,
      type: patient_identifier_type(TB_NUMBER_IDENTIFIER_NAME),
      patient_id: patient_id,
      location_id: Location.current.location_id,
      date_created: Time.now
    )
  end

  private
  def generate_tb_number()
    "#{get_facility_code}-TB-#{SecureRandom.hex}"
  end

  def get_facility_code
    global_property(FACILITY_CODE_GLOBAL_PROPERTY_NAME)&.property_value
  end
end