# frozen_string_literal: true

module Api
  module V1
    class PatientIdentifiersController < ApplicationController
      before_action :set_patient_identifier, only: %i[show update destroy]

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
        params[:location_id] = Location.current.location_id

        identifier = PatientIdentifierService.create(patient_identifier_params)

        if identifier.errors.empty?
          render json: identifier, status: :created
        else
          render json: identifier.errors, status: :bad_request
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

      # Finds all duplicate identifiers of a given type.
      #
      # Renders a list of duplicate identifiers and their counts.
      def duplicates
        id_type = PatientIdentifierType.find(params.require(:type_id))
        render json: service.find_duplicates(id_type)
      end

      def multiples
        id_type = PatientIdentifierType.find(params.require(:type_id))
        render json: service.find_multiples(id_type)
      end

      def archive_active_filing_number
        itypes = PatientIdentifierType.where(name: ['Filing number', 'Archived filing number'])
        identifier_types = itypes.map(&:id)

        PatientIdentifier.where(patient_id: params[:patient_id],
                                identifier_type: identifier_types).select do |i|
          i.void("Voided by #{User.current.username}")
        end

        filing_service = FilingNumberService.new
        identifier = filing_service.find_available_filing_number('Archived filing number')
        archive_number = PatientIdentifier.create(patient_id: params[:patient_id],
                                                  identifier_type: PatientIdentifierType.find_by_name('Archived filing number').id,
                                                  identifier:, location_id: Location.current.id)

        render json: archive_number, status: :created
      end

      def void_multiple_identifiers
        identifiers = params[:identifiers]
        reason = params[:reason] || "Voided by #{User.current.username}"
        identifiers.each do |data|
          PatientIdentifier.find(data).void(reason)
        end
        render status: :no_content
      end

      def swap_active_number
        primary_patient_id    = params[:primary_patient_id]
        secondary_patient_id  = params[:secondary_patient_id]
        identifier            = params[:identifier]

        result = service.swap_active_number(primary_patient_id:,
                                            secondary_patient_id:, identifier:)

        render json: result
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

      def service
        PatientIdentifierService
      end
    end
  end
end
