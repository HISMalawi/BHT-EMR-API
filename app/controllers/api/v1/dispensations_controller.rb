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
end
