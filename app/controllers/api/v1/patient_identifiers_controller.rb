class Api::V1::PatientIdentifiersController < ApplicationController
  before_action :set_patient_identifier, only: [:show, :update, :destroy]

  # GET /patient_identifiers
  def index
    query = PatientIdentifier
    query = query.where(identifier_type: params[:identifier_type]) if params[:identifier_type]
    query = query.where(patient_id: params[:patient_id]) if params[:patient_id]

    render json: paginate(query)
  end

  # GET /patient_identifiers/1
  def show
    render json: @patient_identifier
  end

  # POST /patient_identifiers
  def create
    @patient_identifier = PatientIdentifier.new(patient_identifier_params).tap do |hash|
      hash[:location_id] = Location.current.id
    end

    if @patient_identifier.save
      render json: @patient_identifier, status: :created
    else
      render json: @patient_identifier.errors, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /patient_identifiers/1
  def update
    if @patient_identifier.update(patient_identifier_params)
      render json: @patient_identifier
    else
      render json: @patient_identifier.errors, status: :unprocessable_entity
    end
  end

  # DELETE /patient_identifiers/1
  def destroy
    if @patient_identifier.void("Voided by #{User.current.username}")
      render status: :no_content
    else
      render status: :internal_server_error, json: @patient_identifier.errors
    end
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_patient_identifier
    @patient_identifier = PatientIdentifier.find(params[:id])
  end

  # Only allow a trusted parameter "white list" through.
  def patient_identifier_params
    params.permit(:patient_id, :identifier, :identifier_type)
  end
end
