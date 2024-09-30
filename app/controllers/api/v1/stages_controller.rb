module Api
  module V1
    class StagesController < ApplicationController

      def index
        stageName = params[:stage]
        stages = Stage.includes(:patient)
                       .joins(:visit)
                       .where(visits: { closedDateTime: nil })  
                       .where(stages: { status: true }) 
                       .where(stages: { stage: stageName })

        stages_with_names = stages.map do |stage|
          stage.as_json.merge(
              fullName: stage.patient.name
            )
        end

        render json: stages_with_names, status: :ok
      end

      def create

        patient_id = params[:stage][:patient_id]

        active_visit = Visit.find_by(patientId: patient_id, closedDateTime: nil)

        Rails.logger.debug("======>Patient ID<========: #{patient_id}")
        Rails.logger.debug("======>Active visit<========: #{active_visit.inspect}")

        if active_visit.nil?
          render json: { errors: 'The patient does not have an active visit' }, status: :unprocessable_entity
          return
        end


        stage = Stage.new(stage_params.merge(visit_id: active_visit.id))

        
        if stage.save
          render json: { message: 'Stage created successfully', stage: stage }, status: :created
        else
          render json: { errors: stage.errors.full_messages }, status: :unprocessable_entity
        end
      end

      private

      def stage_params
        params.require(:stage).permit(:patient_id, :stage, :arrivalTime, :visit_id, :status)
      end
    end
  end
end
