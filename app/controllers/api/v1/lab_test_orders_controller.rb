# frozen_string_literal: true

class Api::V1::LabTestOrdersController < ApplicationController
  include LabTestsEngineLoader

  def index
    if params[:accession_number]
      orders = engine.find_orders_by_accession_number params[:accession_number]
      render json: orders
    elsif params[:patient_id]
      patient = Patient.find params[:patient_id]
      orders = engine.find_orders_by_patient patient
      # NOTE: orders can't be paginated here as it is just an ordinary array
      # not a queryset
      render json: orders
    else
      render json: { errors: ['accession_number or patient_id required'] },
             status: :bad_request
    end
  end

  def create
    specimen_type, test_types, encounter_id, reason, target_lab = params.require %i[
      specimen_type test_types encounter_id reason target_lab
    ]

    begin
      date = params[:date]&.to_datetime || Time.now
    rescue ArgumentError => e
      error = "Failed to parse date(#{params[:date]}): #{e}"
      return render json: { errors: [error] }, status: :bad_request
    end

    encounter = Encounter.find encounter_id

    order = engine.create_order specimen_type: specimen_type,
                                test_types: test_types,
                                encounter: encounter,
                                date: date, reason: reason,
                                target_lab: target_lab

    render json: order, status: :created
  end

  def locations
    render json: engine.lab_locations
  end

  def labs
    render json: engine.labs
  end
end
