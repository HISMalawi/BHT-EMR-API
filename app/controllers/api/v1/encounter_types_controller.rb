# frozen_string_literal: true

module Api
  module V1
    class EncounterTypesController < ApplicationController
      def index
        search_params, = required_params optional: %i[name]

        if search_params.empty?
          render json: paginate(EncounterType)
        else
          render json: paginate(EncounterType.where(search_params))
        end
      end
    end
  end
end
