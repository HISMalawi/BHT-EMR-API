# frozen_string_literal: true

class Api::V1::DispensationsController < ApplicationController
  def create
    dispensations = params.require(:dispensations)

    obs_list, error = DispensationService.create dispensations
    if error
      render json: obs_list, status: :bad_request
    else
      render json: obs_list, status: :created
    end
  end

  def index
    patient_id = params.require %i[patient_id]

    if params[:date]
      date = params[:date] ? Date.strptime(params[:date]) : Time.now
      dispensing = EncounterService.recent_encounter encounter_type_name: 'Dispensing',
                                                     patient_id: patient_id,
                                                     date: date
      obs = dispensing ? dispensing.observations : []
    else
      obs = Observation.where(patient_id: patient_id).order(date_created: :desc)
    end

    drug_orders = obs.map(&:drug_order).reject(&:nil?)

    render json: drug_orders
  end
end
