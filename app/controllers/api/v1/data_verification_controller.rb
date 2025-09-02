# frozen_string_literal: true

module Api
  module V1
    class DataVerificationController < ApplicationController
      
      def encounters_done_per_provider
        render json: service.encounters_done_per_provider(parameters)
      end      
      
      def password_changes
        render json: service.password_changes(parameters)
      end


      def encounters_done_odd_hours
        render json: service.encounters_done_odd_hours(parameters)
      end
      
      def parameters
        start_date = params[:start_date]
        end_date = params[:end_date]
        program_id = params[:program_id]

        {
          start_date:,
          end_date:,
          program_id:
        }
      end

      def service
        DataVerificationService.new
      end
    end
  end
end