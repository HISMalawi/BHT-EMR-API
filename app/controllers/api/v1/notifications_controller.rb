# frozen_string_literal: true

module Api
  module V1
    # Fallback to the original notification service.
    class NotificationsController < ApplicationController
      after_action :clear_notifications, only: %i[update clear index]
      def index
        render json: service.uncleared
      end

      def update
        service.read(params[:alerts])
        render json: { success: true }
      end

      def clear
        service.clear(params[:id])
        render json: { success: true }
      end

      private

      def clear_notifications
        NotificationClearJob.perform_later
      end

      def service
        @service ||= NotificationService.new
      end
    end
  end
end
