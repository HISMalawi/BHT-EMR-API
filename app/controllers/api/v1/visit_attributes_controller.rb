# frozen_string_literal: true

module Api
    module V1
      class VisitAttributesController < ApplicationController
        before_action :set_visit_attribute, only: %i[show update destroy]
  
        respond_to :json
  
        def index
          @visit_attributes = VisitAttribute.all
          respond_with(@visit_attributes)
        end
  
        def show
          respond_with(@visit_attribute)
        end
  
        def create
          @visit_attribute = VisitAttribute.new(visit_attribute_params)
          @visit_attribute.save
          respond_with(@visit_attribute)
        end
  
        def update
          @visit_attribute.update(visit_attribute_params)
          respond_with(@visit_attribute)
        end
  
        def destroy
          @visit_attribute.destroy
          respond_with(@visit_attribute)
        end
  
        private
  
        def set_visit_attribute
          @visit_attribute = VisitAttribute.find(params[:id])
        end
  
        def visit_attribute_params
          params.require(:visit_attribute).permit(:visit_id, :attribute_type_id, :value_reference, :uuid, :creator,
                                                  :date_created, :changed_by, :date_changed, :voided, :voided_by, :date_voided, :void_reason)
        end
      end
    end
  end