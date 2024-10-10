module Api
  module V1
    class StagesController < ApplicationController

      VALID_STAGES = %w[VITALS CONSULTATION DISPENSATION].freeze

      #def index
      #  stageName = params[:stage]
      #  stages = Stage.includes(:patient)
      #                 .joins(:visit)
      #                 .where(visits: { closedDateTime: nil })  
      #                 .where(stages: { status: true }) 
      #                 .where(stages: { stage: stageName })

      #  stages_with_names = stages.map do |stage|
      #    stage.as_json.merge(
      #        fullName: stage.patient.name
      #      )
      #  end

      #  render json: stages_with_names, status: :ok
      #end
      def index
        
        stageName = params[:stage] 
        location_id = params[:location_id]    
      
        stages = Stage.includes(:patient)
                      .joins(:visit)
                      .where(visits: { closedDateTime: nil })
                     # .where(stages: { status: true}) 
                      .distinct 
                      
            
        if stageName.present? && location_id.present?    
          stages = stages.where(stage: stageName, location_id: location_id, status: true)
        elsif stageName.present?
          stages = stages.where(stage: stageName, status: true)
        elsif location_id.present?
          stages = stages.where(location_id: location_id, status: true)
        else
          # Return all stages when status is false
          stages = Stage.where(status: false).distinct   
        end
        
        
        # Prepare the result by adding fullName to the stage object
        stages_with_names = stages.map do |stage|
          stage.as_json.merge(
            fullName: stage.patient.name,   
            location_id: stage.location_id
          )
        end
      
        # Return the result as JSON
        render json: stages_with_names, status: :ok
      end
      

      def create

        patientId = params[:stage][:patient_id]

        # validate stage name
        requestedStage = params[:stage][:stage]
        unless VALID_STAGES.include?(requestedStage)
          render json: { errors: "#{requestedStage} is not a valid stage. Allowed stages are: #{VALID_STAGES.join(', ')}" }, status: :unprocessable_entity
          return
        end


     
        activeVisit = Visit.find_by(patientId: patientId, closedDateTime: nil)
        if activeVisit.nil?
          render json: { errors: 'The patient does not have an active visit' }, status: :unprocessable_entity
          return
        end

        
        active_stage = Stage.find_by(patient_id: patientId, status: true)  
        if active_stage
          begin
            active_stage.update!(status: false)
          rescue ActiveRecord::RecordInvalid => e
            Rails.logger.debug("Failed to update status: #{e.message}")
          end
        end


        stage = Stage.new(stage_params.merge(visit_id: activeVisit.id, status: params[:stage][:status] || true))
        
        if stage.save
          render json: { message: 'Stage created successfully', stage: stage }, status: :created
        else
          render json: { errors: stage.errors.full_messages }, status: :unprocessable_entity
        end
      end

      private
      def stage_params
        params.require(:stage).permit(:patient_id, :stage, :arrivalTime, :visit_id, :status, :location_id)
      end
    end
  end
end
