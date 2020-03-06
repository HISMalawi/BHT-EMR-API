class Api::V1::ProgramRegimensController < ApplicationController
  def index
    if params[:patient_id]
      render json: service.find_regimens_by_patient(patient)
    elsif params[:weight]
      use_tb_dosage = params[:tb_dosage]&.casecmp?('true')
      render json: service.find_regimens(params[:weight], use_tb_dosage: use_tb_dosage)
    else
      render json: { error: 'patient_id or weight required' }, status: :bad_request
    end
  end

  def find_starter_pack
    regimen, weight = params.require(%i[regimen weight])
    render json: service.find_starter_pack(regimen, weight)
  end

  def show
    regimen = params[:id]
    lpv_drug_type = params.require(:lpv_drug_type)

    render json: service.regimen(patient, regimen, lpv_drug_type: lpv_drug_type).values[0]
  end

  def custom_regimen_ingredients
    render json: service.custom_regimen_ingredients
  end

  def custom_tb_ingredients
    render json: service.custom_regimen_ingredients(patient: patient)
  end

  private

  def patient(patient_id = nil)
    patient_id ||= params.require(:patient_id)
    Patient.find(patient_id)
  end

  def service
    program_id = params.require(:program_id)
    RegimenService.new(program_id: program_id)
  end
end
