class Api::V1::ProgramRegimensController < ApplicationController
  def index
    weight = params[:weight]
    age = params[:age]
    validate_params weight: weight, age: age

    regimens = service.find_regimens weight: weight, age: age

    render json: regimens
  end

  private

  def validate_params(age:, weight:)
    raise InvalidParameterError, 'weight or age required' unless weight || age
  end

  def service
    return @service if @service

    program_id, = params.require %i[program_id]

    @service = RegimenService.new program_id: program_id
  end
end
