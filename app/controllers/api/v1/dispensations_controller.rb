# frozen_string_literal: true

class Api::V1::DispensationsController < ApplicationController
  def create
    dispensations = params.require(:dispensations)

    render json: DispensationService.create(dispensations), status: :created
  rescue InvalidParameterError => e
    render json: { errors: [e.getMessage, e.model_errors] }, status: :bad_request
  end

  def index
    patient_id = params.require %i[patient_id]

    obs_list = DispensationService.dispensations patient_id, params[:date]
    render json: paginate(obs_list)
  end
end
