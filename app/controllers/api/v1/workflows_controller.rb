# frozen_string_literal: true

class Api::V1::WorkflowsController < ApplicationController
  # Retrieves patient's next encounter given previous encounters
  # and enrolled program
  def next_encounter
    program_id, patient_id = params.require(%i[program_id patient_id])
    date = params[:date]

    engine = WorkflowService::EngineLoader.load_engine program_id: program_id,
                                                       patient_id: patient_id,
                                                       date: date

    encounter = engine.next_encounter

    if encounter
      render json: encounter
    else
      render status: :no_content
    end
  rescue WorkflowService::Exceptions::WorkflowError => e
    render json: { errors: e.to_s }, status: :bad_request
  end
end
