# frozen_string_literal: true

class Api::V1::PatientsController < ApplicationController
  before_action :load_dde_service

  def show
    render json: @dde_service.all_patients
  end

  def get
    patient = @dde_service.find_patient(params[:id])
    unless patient
      errors = ["Patient ##{params[:id]} not found"]
      render json: { errors: errors }, status: :bad_request
      return
    end
    render json: patient
  end

  def create
    # patient = @dde_service.create_patient()
  end

  protected

  def load_dde_service
    @dde_service = DDEService.instance
  end
end
