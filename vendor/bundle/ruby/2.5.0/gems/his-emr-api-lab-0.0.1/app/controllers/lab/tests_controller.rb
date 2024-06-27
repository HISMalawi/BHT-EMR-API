# frozen_string_literal: true

class Lab::TestsController < ::ApplicationController
  def index
    filters = params.permit(%i[order_date accession_number patient_id test_type_id specimen_type_id pending_results])

    tests = service.find_tests(filters)
    render json: tests
  end

  # Add a specimen to an existing order
  def create
    test_params = params.permit(:order_id, :date, tests: [:concept_id])
    order_id, test_concepts = test_params.require(%i[order_id tests])
    date = test_params[:date] || Date.today

    tests = service.create_tests(Order.find(order_id), date, test_concepts)

    render json: tests, status: :created
  end

  def service
    Lab::TestsService
  end
end
