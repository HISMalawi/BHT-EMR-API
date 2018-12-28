class Api::V1::Types::PatientIdentifiersController < ApplicationController
  # GET /types/patient_identifiers
  def index
    name = params[:name]

    query = PatientIdentifierType
    query = query.where('name like ?', name) if name

    render json: paginate(query)
  end

  # GET /types/patient_identifiers/1
  def show
    render json: PatientIdentifierType.find(params[:id])
  end
end
