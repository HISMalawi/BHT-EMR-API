# frozen_string_literal: true

module Api
  module V1
    module Types
      class PatientIdentifiersController < ApplicationController
        # GET /types/patient_identifiers
        def index
          name = params[:name]

          query = PatientIdentifierType

          query = if name
                    query.where('name like ?', "#{name}%")
                  else
                    query.all
                  end

          render json: query
        end

        # GET /types/patient_identifiers/1
        def show
          render json: PatientIdentifierType.find(params[:id])
        end
      end
    end
  end
end
