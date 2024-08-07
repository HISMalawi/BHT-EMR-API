# frozen_string_literal: true

class Lab::TestResultIndicatorsController < ApplicationController
  def index
    test_type_id = params.require(:test_type_id)

    render json: Lab::ConceptsService.test_result_indicators(test_type_id)
  end
end
