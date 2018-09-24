# frozen_string_literal: true

class Api::V1::DispensationsController < ApplicationController
  def create
    dispensations = params.require(:dispensations)

    obs_list, error = DispensationService.create dispensations
    if error
      render json: obs_list, status: :bad_request
    else
      render json: obs_list, status: :created
    end
  end

  def index
    patient_id = params.require %i[patient_id]

    obs_list = DispensationService.dispensations patient_id, params[:date]
    render json: paginate(obs_list)
  end
end
