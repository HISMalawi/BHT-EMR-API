# frozen_string_literal: true

module Api
  module V1
    class UserRolesController < ApplicationController
      def index
        render json: service.user_roles(user)
      end

      private

      def user
        params[:user_id].nil? ? User.current : User.find(params[:user_id])
      end

      def service
        UserService
      end
    end
  end
end
