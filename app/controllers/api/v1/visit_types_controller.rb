# frozen_string_literal: true

module Api
    module V1
      class VisitTypesController < ApplicationController
        before_action :set_visit_type, only: %i[show update destroy]
  
        #respond_to :json
  
        def index

          @visit_types = VisitType.all

          respond_to do |format|
            format.json { render json: @visit_types }  
          end   
          paginate VisitType.all
        end
  
        def show
          render json: VisitType.find_by_uuid(params[:id])
        end
  
        def create
          render json: VisitType.create(visit_type_params)
        end
  
        def update
          render json: VisitType.find_by_uuid(params[:id]).update(visit_type_params)
        end
  
        def destroy
          render json: VisitType.find_by_uuid(params[:id]).void(params[:void_reason])
        end
  
        private
  
        def visit_type_params
          params.permit(:name, :description)
        end
      end
    end
  end