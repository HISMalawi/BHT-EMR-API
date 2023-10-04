# frozen_string_literal: true

module Api
  module V1
    class GlobalPropertiesController < ApplicationController
      def search
        name, = params.require %i[property]

        render json: GlobalProperty.where('property like ?', "%#{name}%")
      end

      def show
        name = params.require %i[property]
        property = GlobalProperty.find_by property: name
        if property
          render json: { property.property => property.property_value }
        else
          render json: { errors: ["Property, #{name}, not found"] },
                 status: :not_found
        end
      end

      def create(success_response_status: :created)
        name, value = params.require %i[property property_value]

        property = GlobalProperty.find_by property: name
        property ||= GlobalProperty.new property: name
        property.property_value = value

        if property.save
          render json: property, status: success_response_status
        else
          render json: ['Failed to save property'],
                 status: :internal_server_error
        end
      end

      def update
        create success_response_status: :ok
      end

      def destroy
        name = params.require %i[property]
        property = GlobalProperty.find_by(name:)
        if property.nil?
          render json: { errors: ["Property, #{name}, not found"] }
        elsif property.destroy
          render status: :no_content
        else
          render json: { errors: property.errors }, status: :internal_server_error
        end
      end
    end
  end
end
