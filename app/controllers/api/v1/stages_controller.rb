module Api
    module V1
      class StagesController < ApplicationController

      
        # GET /api/v1/stag pes
        def index
          stages = Stage.includes(:patient).all

          stages_with_names = stages.map do |stage|
          
            stage.as_json.merge(
                fullName: stage.patient.name
            )
          end
          render json: stages_with_names, status: :ok
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
          params.permit(:patient_id, :stage, :arrivalTime, :visit_id, :status)
        end
      end
    end
  end
  