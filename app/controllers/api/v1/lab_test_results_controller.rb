# frozen_string_literal: true

class Api::V1::LabTestResultsController < ApplicationController
  include LabTestsEngineLoader

  def index
    render json: engine.results(params[:accession_number])
  end

  def create
    accession_number, test_value = params.require %i[accession_number test_value time]

    result = engine.save_result accession_number: accession_number,
                                test_value: test_value,
                                time: time&.to_datetime || Time.now
    render json: result, status: :created
  end
end
