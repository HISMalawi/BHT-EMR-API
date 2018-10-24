# frozen_string_literal: true

class Api::V1::LabTestOrdersController < ApplicationController
  def create
    lab_test_type_id, encounter_id = params.require %i[test_type_id encounter_id]

    type = LabTestType.find(lab_test_type_id)
    encounter = Encounter.find(encounter_id)
    order = engine.create_order type: type, encounter: encounter

    render json: order
  end

  private

  def engine
    ARTService::LabTestsEngine.new program: nil
  end
end
