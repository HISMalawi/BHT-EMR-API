# frozen_string_literal: true

module Api
  module V1
    class PresentingComplaintsController < ApplicationController
      def show
        render json: service.get_complaints(params[:id])
      end

      private

      def service
        PresentingComplaintService.new
      end
    end
  end
end
