# frozen_string_literal: true

module Api
  module V1
    class LabTestTypesController < ApplicationController
      include LabTestsEngineLoader

      def index
        response = engine.types search_string: params[:search_string]

        render json: response
      end

      def panels
        test_type = params.require(:test_type)
        response = engine.panels test_type
        if response
          render json: response
        else
          render json: { message: "test type not found: #{test_type}" }, status: :not_found
        end
      end

      def measures
        test_name = params.require(:test_name)
        render json: engine.test_measures(test_name)
      end
    end
  end
end
