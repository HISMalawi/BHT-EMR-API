# frozen_string_literal: true

class Api::V1::LabTestOrdersController < ApplicationController
  def create
    lab_test_type_id, encounter_id = params.require %i[test_type_id encounter_id]

    begin
      date = params[:date] ? params[:date].to_date : nil
    rescue ArgumentError => e
      error = "Failed to parse date(#{params[:date]}): #{e}"
      return render json: { error: error }, status: :bad_request
    end

    type = LabTestType.find lab_test_type_id
    encounter = Encounter.find encounter_id
    order = engine.create_order type: type, encounter: encounter, date: date

    render json: order
  end

  private

  def engine
    ARTService::LabTestsEngine.new program: nil
  end
end
