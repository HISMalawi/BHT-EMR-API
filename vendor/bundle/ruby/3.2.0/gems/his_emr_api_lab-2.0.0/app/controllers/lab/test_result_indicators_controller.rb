# frozen_string_literal: true

module Lab
  class TestResultIndicatorsController < ApplicationController
    def index
      test_type_id = params.require(:test_type_id)

      render json: Lab::ConceptsService.test_result_indicators(test_type_id)
    end
  end
end
