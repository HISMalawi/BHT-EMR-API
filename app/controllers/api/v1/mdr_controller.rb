class Api::V1::MdrController < ApplicationController

  def create_custom_regimen
    drugs = params[:drugs]
    duration = params[:duration]
    short_code = params[:code]

    render json: service.create_custom_regimen(drugs, duration, short_code)
  end

  def new_regimen
    regimen = params[:regimen]
    render json: service.new_regimen(regimen)
  end

  def regimen_types
    render json: service.get_regimens
  end

  def custom_regimen_options
    render json: service.get_custom_regimen_options
  end

  def active_regimen
    render json: service.get_regimen_status
  end

  def next_phase
    render json: service.go_to_next_phase
  end

  def service
    patient = params[:patient_id]
    program = params[:program_id]
    date = params[:date]
    patient_service = PatientService.new
    starting_from_date = patient_service.patient_last_outcome_date(patient, program, date)

    TbService::TbMdrService.new patient, program, date, starting_from_date
  end
end
