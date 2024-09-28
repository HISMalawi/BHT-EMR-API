module Api
    module V1
        class Api::V1::VisitsController < ApplicationController
            def check_patient_status
                patientId = params[:patient_id]
                visit = Visit.where(patientId: patientId, closedDateTime: nil)

                if visit.empty?
                    render json: { message: "No Active visit found for patientId #{patientId}" }, status: :not_found
                  else
                    render json: visit, status: :ok
                  end

            end
            def create
                visit = Visit.new(visit_params)
                if visit.save
                    render json: {message:"Visit created successfully", visit: visit}, status: :created
                else
                    render json: { errors: visit.errors.full_messages }, status: :unprocessable_entity
                end
            end

            private

            def visit_params
                params.require(:visit).permit(:patientId, :startDate, :closedDateTime, :programId)
            end

        end
    end
end
