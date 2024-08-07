# frozen_string_literal: true

module Api
  module V1
    module Types
      class RelationshipsController < ApplicationController
        def index
          types = service.find search_string: params[:search_string]
          render json: paginate(types)
        end

        private

        def service
          @service ||= RelationshipTypeService.new
        end
      end
    end
  end
end
