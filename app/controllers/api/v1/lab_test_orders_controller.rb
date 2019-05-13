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
    tests, encounter_id, requesting_clinician = params.require %i[
      tests encounter_id requesting_clinician
    ]

    begin
      date = TimeUtils.retro_timestamp(params[:date]&.to_time || Time.now)
    rescue ArgumentError => e
      error = "Failed to parse date(#{params[:date]}): #{e}"
      return render json: { errors: [error] }, status: :bad_request
    end

    encounter = Encounter.find encounter_id

    order = engine.create_order tests: tests,
                                encounter: encounter,
                                date: date,
                                requesting_clinician: requesting_clinician

    render json: order, status: :created
  end

  def locations
    search_name = params[:search_name]

    locations_list = engine.lab_locations
    if search_name
      locations_list = locations_list.select { |location| location.include?(search_name) }
    end

    render json: locations_list
  end

  def labs
    search_name = params[:search_name]

    labs_list = engine.labs
    if search_name
      labs_list = labs_list.select { |labs| labs.include?(search_name) }
    end

    render json: labs_list
  end

  def orders_without_results
    render json: engine.orders_without_results(patient)
  end

  private

  def patient
    Patient.find(params[:patient_id])
  end
end
