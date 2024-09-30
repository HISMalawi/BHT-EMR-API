module Api
    module V1
        class Api::V1::VisitsController < ApplicationController
            def check_patient_status
                patientId = params[:patient_id]
                visit = Visit.where(patientId: patientId, closedDateTime: nil)

                if visit.empty?
                    render json: { message: "No Active visit found for patient with Id #{patientId}" }, status: :not_found
                  else
                    render json: visit, status: :ok
                  end

            end
            def create
                patientId = visit_params[:patientId]
                checkPatient = Patient.find_by(patient_id: patientId)

                if checkPatient.nil?
                    render json: { message: "patient with ID #{patientId} doesnt exist " }, status: :conflict
                    return
                end

                checkVisit = Visit.where(patientId: patientId, closedDateTime: nil)
                if checkVisit.exists?
                    render json: { message: "there is an active visit for patient with #{patientId}" }, status: :conflict
                    return
                end

                visit = Visit.new(visit_params)
                if visit.save
                    render json: {message:"Visit created successfully", visit: visit}, status: :created
                else
                    render json: { errors: visit.errors.full_messages }, status: :unprocessable_entity
                end
            end


            def close
                visitId= params[:id]
                visit = Visit.find_by(id: visitId);

                if visit.nil?
                    render json: { errors: "visit with id #{visitId} doesn't exist" }, status: :unprocessable_entity
                    return
                end
                visit.update(closedDateTime: params[:visit][:closedDateTime]);

                activeStage = Stage.find_by(patient_id:visit.patientId, status: true)

                if activeStage
                    begin
                      activeStage.update!(status: false)
                    rescue ActiveRecord::RecordInvalid => e
                      Rails.logger.debug("Failed to update status: #{e.message}")
                    end
                end 
            end

            private
            def visit_params
                params.require(:visit).permit(:patientId, :startDate, :closedDateTime, :programId)
            end

        end
    end
end
