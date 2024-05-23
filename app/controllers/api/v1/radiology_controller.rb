# frozen_string_literal: true

# radiology controller
module Api
  module V1
    class RadiologyController < ApplicationController
      def show
        render json: { message: 'Hello World' }
      end

      def examinations
        render json: investigation_service.all_examinations
      end

      private

      def investigation_service
        @investigation_service ||= RadiologyService::Investigation.new(patient_id: params.require(:patient_id),
                                                                       date: params[:date] || Date.today)
      end
    end
  end
end
