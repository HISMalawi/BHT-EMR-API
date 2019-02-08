# frozen_string_literal: true

class Api::V1::LabTestTypesController < ApplicationController
  include LabTestsEngineLoader

  def index
    response = engine.types search_string: params[:search_string]

    render json: response
  end

  def panels
    test_type = params.require %i[test_type]
    response = engine.panels search_string: test_type
    if response
      render json: response
    else
      render json: { message: "test type not found: #{test_type}" }, status: :not_found
    end
  end

  def tb_panels
    response = engine.panels
    if response
      render json: response
    else
      render json: { message: "test type not found" }, status: :not_found
    end
  end
end
