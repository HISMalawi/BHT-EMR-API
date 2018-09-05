class Api::V1::EncounterTypesController < ApplicationController
  def index
    render json: paginate(EncounterType)
  end
end
