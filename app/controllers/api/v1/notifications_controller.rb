# frozen_string_literal: true

module Api
  module V1
    # Fallback to the original notification service.
    class NotificationsController < ApplicationController
      def index
        render json: service.unread
      end

      def update
        service.read(params[:alerts])
        render json: { success: true }
      end

      private

      def service
        @service ||= NotificationService.new
      end
    end
  end
end
