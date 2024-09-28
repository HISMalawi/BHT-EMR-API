module Api
    module V1
        class Api::V1::VisitsController < ApplicationController
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
