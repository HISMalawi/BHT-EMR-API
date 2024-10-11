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


            def index
              patientId = params[:patientId] # Optional filter by patient ID
              status = params[:status] # Optional filter by status (active or closed)
            
              # Fetch all visits, optionally filtering by patientId or status
              #visits = Visit.all
              visits = Visit.select('MIN(id) as id, patientId, startDate, closedDateTime, location_id, programId')
              .group(:patientId)  
            
              # Filter by patientId if provided
              visits = visits.where(patientId: patientId) if patientId.present?
            
              # Filter by status (closed or active visits) if provided
              if status.present?
                case status.downcase
                when 'active'
                  visits = visits.where(closedDateTime: nil)
                when 'closed'
                  visits = visits.where.not(closedDateTime: nil)  
                end
              end

              visits = visits.where('startDate >= ?', Time.now)    
            
              # Return the list of visits as JSON
              render json: visits, status: :ok
            end   
            


            #def close   
                       
            #    visitId = params[:id]
            #    visit = Visit.find_by(id: visitId);

            #    if visit.nil?
            #        render json: { errors: "visit with id #{visitId} doesn't exist" }, status: :unprocessable_entity
            #        return
            #    end
            #    visit.update(closedDateTime: params[:visit][:closedDateTime]);

            #    activeStage = Stage.find_by(patient_id:visit.patientId, status: true)

            #    if activeStage
            #        begin
            #          activeStage.update!(status: false)
            #        rescue ActiveRecord::RecordInvalid => e
            #          Rails.logger.debug("Failed to update status: #{e.message}")
            #        end
            #    end 
            #end
            def close
                visit_id = params[:id]
                visit = Visit.find_by(id: visit_id)
              
                unless visit
                  render json: { errors: "Visit with id #{visit_id} doesn't exist" }, status: :unprocessable_entity
                  return
                end
              
                closed_datetime = params.dig(:visit, :closedDateTime)
                visit.update(closedDateTime: closed_datetime)
              
                active_stage = Stage.find_by(patient_id: visit.patientId, status: true)

              
                if active_stage
                  begin
                    active_stage.update!(status: false)
                  rescue ActiveRecord::RecordInvalid => e
                    Rails.logger.debug("Failed to update stage status: #{e.message}")
                  end
                end
              end
              

            private
            def visit_params
                params.require(:visit).permit(:patientId, :startDate, :closedDateTime, :programId, :location_id)
            end

        end
    end   
end
