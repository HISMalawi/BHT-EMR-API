class Api::V1::ProgramRegimensController < ApplicationController
  def index
    regimens = service.find_regimens patient
    render json: regimens
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
