module Api
  module V1
    class StagesController < ApplicationController
      VALID_STAGES = %w[VITALS CONSULTATION LAB DISPENSATION].freeze
      include CouchdbSync

      def index
        stageName   = params[:stage]
        location_id = params[:location_id]
        patient_id  = params[:patient_id]
        identifier  = params[:identifier]

        stages = Stage
                .includes(patient: :patient_identifiers)
                .joins(:visit)
                .joins('INNER JOIN patient ON patient.patient_id = visits.patientId')
                .joins('INNER JOIN patient_identifier ON patient_identifier.patient_id = patient.patient_id AND patient_identifier.identifier_type = 3')
                .where(visits: { closedDateTime: nil })
                .distinct

        stages = stages.where(status: true)
        stages = stages.where(patient_id: patient_id) if patient_id.present?
        stages = stages.where("patient_identifier.identifier = ?", identifier) if identifier.present?
        stages = stages.where(stage: stageName) if stageName.present?
        stages = stages.where(location_id: location_id) if location_id.present?

        stages_with_info = stages.map do |stage|
        # Find the identifier with type 3 from preloaded identifiers
        type3_identifier = stage.patient.patient_identifiers.find { |pi| pi.identifier_type == 3 }&.identifier

        stage.as_json.merge(
          fullName: stage.patient.name,
          identifier: type3_identifier,
          location_id: stage.location_id
        )
        end

        render json: stages_with_info, status: :ok
      end

      def active_stages
        begin
          # Get current user's location_id
          current_location_id = User.current.location_id
          
          if current_location_id.nil?
            render json: { errors: 'Current user does not have a location assigned' }, status: :unprocessable_entity
            return
          end
          
          # Get active stages for the current location
          # Active stages are those with status: true and visits that are not closed
          active_stages = Stage.includes(:patient)
                              .joins(:visit)
                              .where(
                                location_id: current_location_id,
                                visits: { closedDateTime: nil }
                              )
                              .distinct
          
          # Return stages as is (to JSON)
          render json: active_stages, status: :ok
          
        rescue => e
          Rails.logger.error("Error fetching active stages: #{e.message}")
          render json: { errors: "An error occurred while fetching active stages: #{e.message}" }, status: :internal_server_error
        end
      end

      def create
        data = StagesService.new.create_stage(stage_params)
        sync_to_couchdb(data, "stages", data[:identifier])
        render json: data
      end

      private

      def stage_params
        params.permit(:patient_id, :identifier, :stage, :arrivalTime, :location_id)
      end
    end
  end
end