# frozen_string_literal: true

class Api::V1::LabTestResultsController < ApplicationController
  include LabTestsEngineLoader

  def create
    accession_number, test_type_id, test_value = params.require %i[
      accession_number test_type_id test_value
    ]
    test_type = engine.type test_type_id
    result = engine.create_result accesion_number: accession_number,
                                  test_type: test_type,
                                  test_value: test_value
    render json: result, status: :created
  end
end
