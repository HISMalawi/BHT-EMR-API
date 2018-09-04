class Api::V1::ObservationsController < ApplicationController
  # Retrieve specific observation
  #
  # GET /observations/:id
  def show
    render json: Observation.find(params[:id])
  end

  # Retrieve list of observations
  #
  # GET /observations
  #
  # Optional parameters
  #   ...
  def index
    filters, = required_params optional: %i[]

    render json: paginate(Observation)
  end
end
