# frozen_string_literal: true

module Api
    module V1
      # visits controller
      class VisitsController < ApplicationController
        include ParamConstants
        #respond_to :json
  
        def index

          @visits = Visit.all

          respond_to do |format|
            format.json { render json: @visits }
          end
          paginate VisitService.find_visits(params.permit(ParamConstants::VISIT_SEARCH_PARAMS))
        end
  
        def show
          render json: Visit.find_by_uuid(params[:id]), status: :ok
        end
  
        def create

          #create_params = params.permit ParamConstants::VISIT_WHITELISTED_PARAMS

          create_params = params.require(:visit).permit(*ParamConstants::VISIT_WHITELISTED_PARAMS)
  
          visit = VisitService.create_visit(create_params)
          render json: visit, status: :created
        end
  
        def encounters_done
          render json: Visit.find_by_uuid(params[:uuid]).encounters_done, status: :ok
        end
  
        def daily_visits
          # date = Date.parse(params.permit(:date)
          allowed = params.permit(:category, :date, :open_visits)
          category = allowed[:category]
          open_visits_only = allowed[:open_visits] || true
  
          date = allowed[:date] ? Date.parse(allowed[:date]) : Date.today
  
          render json: VisitService.daily_visits(date:, category:, open_visits_only:), status: :ok
        end
  
        def generate_visit_number
     
          visit_number = VisitService.generate_visit_number
          render json: { next_visit_number: visit_number }, status: :ok    
  
          # close off hanging visits for screening screen
          #visit_number = VisitService.daily_visits(category: 'screening')
  
          #taken_visit_ids = Observation.joins(encounter: :visit).where(
          #  visit: { date_stopped: nil },
          #  obs: { concept_id: ConceptName.find_by_name('OPD Visit number').concept_id }
          #).select('obs.value_numeric')&.map(&:value_numeric)
  
          #visit_number = 1
  
          #visit_number += 1 while taken_visit_ids.include?(visit_number) && not_assigned_today?(visit_number)
  
          #render json: { next_visit_number: visit_number }, status: :ok
        end
  
        def not_assigned_today?(visit_number)
          Observation.where(
            concept_id: ConceptName.find_by_name('OPD Visit number').concept_id,
            value_numeric: visit_number,
            obs_datetime: Time.now.beginning_of_day..Time.now.end_of_day
          ).present?
        end
  
        # Get open visits for a patient
        def open_visits
          render json: Person.find_by_uuid(params[:uuid])&.patient&.open_visits, status: :ok
        end
  
        def update
          #update_params = params.permit ParamConstants::VISIT_WHITELISTED_PARAMS

          update_params = params.require(:visit).permit(*ParamConstants::VISIT_WHITELISTED_PARAMS)
  
          visit = Visit.find_by_uuid(params[:id])     

          render json: VisitService.update_visit(visit, update_params), status: :ok
        end
  
        def destroy
          visit = Visit.find_by_uuid(params[:id]).void(ParamConstants::VISIT_WHITELISTED_PARAMS)
          render status: :ok
        end
      end
    end
  end