# frozen_string_literal: true

module Api
  module V1
    class LabTestResultsController < ApplicationController
      include LabTestsEngineLoader

      def index
        render json: engine.results(params[:accession_number])
      end

      def create
        result = engine.save_result(params[:lab_test_result])
        render json: result, status: :created
      end

      def create_order_and_results
        order, result = params.require(%i[order result])

        order = engine.create_legacy_order(patient, order)
        result[:tracking_number] = order[:lims_order]['tracking_number']
        result = engine.save_result(result)

        render json: { order:, result: }, status: :created
      end

      def patient
        Patient.find(params[:patient_id])
      end
    end
  end
end
