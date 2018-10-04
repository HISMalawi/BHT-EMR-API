class Api::V1::ProgramRegimensController < ApplicationController
  def index
    program_id, weight = params.require %i[program_id weight]

    regimen_engine = RegimenService::EngineLoader.load_engine program_id
    regimens = regimen_engine.find_regimens_by_weight weight

    render json: regimens
  rescue RegimenService::InvalidWeightError => e
    logger.error e
    render json: { errors: [e.to_s] }, status: :bad_request
  end
end
