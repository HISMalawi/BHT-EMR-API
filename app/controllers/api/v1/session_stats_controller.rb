# frozen_string_literal: true

module Api
  module V1
    class SessionStatsController < ApplicationController
      def show
        render json: service.visits
      end

      private

      def service
        permitted_params = params.permit %i[date user_id]
        date = permitted_params[:date]&.to_date || Date.today
        user = permitted_params[:user_id] ? User.find(permitted_params[:user_id]) : User.current

        SessionStatsService.new user, date
      end
    end
  end
end
