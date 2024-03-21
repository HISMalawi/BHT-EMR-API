# frozen_string_literal: true

module Api
  module V1
    class RolesController < ApplicationController
      def index
        render json: paginate(Role)
      end

      def show
        render json: Role.find(params[:id])
      end
    end
  end
end
