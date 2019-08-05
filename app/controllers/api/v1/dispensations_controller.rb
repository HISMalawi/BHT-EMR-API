# frozen_string_literal: true

class Api::V1::DispensationsController < ApplicationController
  def create
    dispensations, program_id = params.require(%i[dispensations program_id])

    program = Program.find(program_id)
    provider = params[:provider_id] ? Person.find(params[:provider_id]) : User.current.person

    render json: DispensationService.create(program, dispensations, provider), status: :created
  rescue InvalidParameterError => e
    render json: { errors: [e.getMessage, e.model_errors] }, status: :bad_request
  end

  def index
    patient_id = params.require %i[patient_id]

    obs_list = DispensationService.dispensations patient_id, params[:date]
    render json: paginate(obs_list)
  end

  def destroy
    order = DrugOrder.find(params[:id])
    service.void_dispensations(order)

    render status: :no_content
  end

  private

  def service
    DispensationService
  end
end
