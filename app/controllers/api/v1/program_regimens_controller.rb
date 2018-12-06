class Api::V1::ProgramRegimensController < ApplicationController
  def index
    weight, age, gender = find_regimen_params
    regimens = service.find_regimens patient_weight: weight,
                                     patient_age: age,
                                     patient_gender: gender
    render json: regimens
  end

  def find_starter_pack
    regimen, weight = params.require(%i[regimen weight])
    render json: service.find_starter_pack(regimen, weight)
  end

  private

  def find_regimen_params
    patient_id = params[:patient_id]
    return params.require(%i[weight age gender]) unless patient_id

    patient = Patient.find patient_id
    [params[:weight] || patient.weight, patient.age, patient.gender]
  end

  def service
    return @service if @service

    program_id, = params.require %i[program_id]
    @service = RegimenService.new program_id: program_id
  end
end
