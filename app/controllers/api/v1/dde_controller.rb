class Api::V1::DdeController < ApplicationController
  # GET /api/v1/dde/patients
  def find_patients_by_npid
    npid = params.require(:npid)
    render json: service.find_patients_by_npid(npid)
  end

  def find_patients_by_name_and_gender
    given_name, family_name, gender = params.require(%i[given_name family_name gender])
    render json: service.find_patients_by_name_and_gender(given_name, family_name, gender)
  end

  def import_patients_by_npid
    npid = params.require(:npid)
    render json: service.import_patients_by_npid(npid)
  end

  def import_patients_by_doc_id
    doc_id = params.require(:doc_id)
    render json: service.import_patients_by_doc_id(doc_id)
  end

  # GET /api/v1/dde/match
  #
  # Returns DDE patients matching demographics passed
  def match_patients_by_demographics
    render json: service.match_patients_by_demographics(match_params)
  end

  def reassign_patient_npid
    dde_person_doc_id = params.require(:dde_person_doc_id)
    render json: service.reassign_patient_npid(dde_person_doc_id)
  end

  def merge_patients
    primary_patient_ids = params.require(:primary)
    secondary_patient_ids = params.require(:secondary)

    render json: service.merge_patients(
      # NOTE: We could directly pass down the objects, however we are
      # doing it like this for the purpose of documentation.
      { 'doc_id' => primary_patient_ids['doc_id'],
        'patient_id' => primary_patient_ids['patient_id'] },
      { 'doc_id' => secondary_patient_ids['doc_id'],
        'patient_id' => secondary_patient_ids['patient_id'] }
    )
  end

  private

  MATCH_PARAMS = %i[given_name family_name gender birthdate home_village
                    home_traditional_authority home_district].freeze

  def match_params
    MATCH_PARAMS.each_with_object({}) do |param, params_hash|
      raise "param #{param} is required" if params[param].blank?

      params_hash[param] = params[param]
    end
  end

  def service
    DDEService.new
  end
end
