# frozen_string_literal: true

module Api
  module V1
    class TimeController < ApplicationController
      skip_before_action :authenticate

      def current_time
        render json: service.current_time
      end

      private

      def service
        TimeService.new
      end
    end
  end
end
