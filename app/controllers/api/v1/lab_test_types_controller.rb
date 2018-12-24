# frozen_string_literal: true

class Api::V1::LabTestTypesController < ApplicationController
  include LabTestsEngineLoader

  def index
    query = engine.types search_string: params[:search_string],
                         specimen_type: params[:specimen_type]

    render json: query
  end

  def panels
    query = engine.panels search_string: params[:search_string]
    render json: query
  end
end
