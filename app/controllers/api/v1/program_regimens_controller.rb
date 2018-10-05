class Api::V1::ProgramRegimensController < ApplicationController
  def index
    program_id, = params.require %i[program_id]
    weight = params[:weight]
    age = params[:age]

    return unless validate_params weight: weight, age: age

    regimen_engine = RegimenService::EngineLoader.load_engine program_id
    regimens = regimen_engine.find_regimens weight: weight, age: age

    render json: regimens
  rescue RegimenService::InvalidWeightError => e
    logger.error e
    render json: { errors: [e.to_s] }, status: :bad_request
  end

  def validate_params(age:, weight:)
    return true if weight || age

    render json: { errors: ['weight or age required'] },
           status: :bad_request
    false
  end
end
