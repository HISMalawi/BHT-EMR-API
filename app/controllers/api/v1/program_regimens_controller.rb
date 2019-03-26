class Api::V1::ProgramRegimensController < ApplicationController
  def index
    regimens = service.find_regimens patient
    render json: regimens
  end

  def find_starter_pack
    regimen, weight = params.require(%i[regimen weight])
    render json: service.find_starter_pack(regimen, weight)
  end

  def pellets_regimen
    regimen, use_pellets = params.require(%i[regimen use_pellets])
    use_pellets = use_pellets.match?(/true/i)
    render json: service.pellets_regimen(patient, regimen, use_pellets).values[0]
  end

  def custom_regimen_ingredients
    render json: service.custom_regimen_ingredients
  end

  private

  def patient
    patient_id, = params.require(%i[patient_id])
    Patient.find(patient_id)
  end

  def service
    return @service if @service

    program_id, = params.require %i[program_id]
    @service = RegimenService.new program_id: program_id
  end
end
