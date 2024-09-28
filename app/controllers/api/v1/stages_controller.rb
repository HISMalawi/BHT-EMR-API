module Api
    module V1
      class StagesController < ApplicationController
        # GET /api/v1/stages
        def index
          stages = Stage.all
          render json: stages, status: :ok
        end
  
        def create
          stage = Stage.new(stage_params)
          if stage.save
            render json: { message: 'Stage created successfully', stage: stage }, status: :created
          else
            render json: { errors: stage.errors.full_messages }, status: :unprocessable_entity
          end
        end
  
        private
        def stage_params
          params.permit(:patientId, :stage, :arrivalTime, :visit_id, :status)
        end
      end
    end
  end
  