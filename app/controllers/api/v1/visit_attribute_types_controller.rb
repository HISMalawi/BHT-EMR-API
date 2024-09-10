# frozen_string_literal: true

module Api
    module V1
      class VisitAttributeTypesController < ApplicationController
        before_action :set_visit_attribute_type, only: %i[show update destroy]
  
        respond_to :json
  
        def index
          @visit_attribute_types = VisitAttributeType.all
          respond_with(@visit_attribute_types)
        end
  
        def show
          respond_with(@visit_attribute_type)
        end
  
        def create
          @visit_attribute_type = VisitAttributeType.new(visit_attribute_type_params)
          @visit_attribute_type.save
          respond_with(@visit_attribute_type)
        end
  
        def update
          @visit_attribute_type.update(visit_attribute_type_params)
          respond_with(@visit_attribute_type)
        end
  
        def destroy
          @visit_attribute_type.destroy
          respond_with(@visit_attribute_type)
        end
  
        private
  
        def set_visit_attribute_type
          @visit_attribute_type = VisitAttributeType.find(params[:id])
        end
  
        def visit_attribute_type_params
          params.require(:visit_attribute_type).permit(:name, :description, :datatype, :datatype_config,
                                                       :preferred_handler, :handler_config, :min_occurs, :max_occurs, :creator, :date_created, :changed_by, :date_changed, :retired, :retired_by, :date_retired, :retire_reason, :uuid)
        end
      end
    end
  end