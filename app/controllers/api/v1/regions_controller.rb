# frozen_string_literal: true

module Api
  module V1
    class RegionsController < ApplicationController
      def index
        render json: paginate(Region)
      end
    end
  end
end
