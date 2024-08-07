# frozen_string_literal: true

module Lab
  class TestsController < ApplicationController
    def index
      filters = params.slice(:order_date, :accession_number, :patient_id, :test_type_id, :specimen_type_id,
                             :pending_results)

      tests = service.find_tests(filters)
      render json: tests
    end

    # Add a specimen to an existing order
    def create
      test_params = params.slice(:order_id, :date, tests: [:concept_id])
      order_id, test_concepts = test_params.require(%i[order_id tests])
      date = test_params[:date] || Date.today

      tests = service.create_tests(Lab::LabOrder.find(order_id), date, test_concepts)
      Lab::PushOrderJob.perform_later(order_id)

      render json: tests, status: :created
    end

    def service
      Lab::TestsService
    end
  end
end
