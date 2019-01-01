# frozen_string_literal: true

class Api::V1::LabTestTypesController < ApplicationController
  include LabTestsEngineLoader

  def index
    response = engine.types search_string: params[:search_string],
                            specimen_type: params[:specimen_type]

    if response
      render json: response
    else
      render json: { message: "Specimen type not found: #{params[:specimen_type]}" },
             status: :not_found
    end
  end

  def panels
    query = engine.panels search_string: params[:search_string]
    render json: query
  end
end
