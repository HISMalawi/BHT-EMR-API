# frozen_string_literal: true

module Api
  module V1
    class DataVerificationController < ApplicationController
      TOOLS = {
        'ENCOUNTERS DONE PER PROVIDER' => 'encounters_done_per_provider',
        'ENCOUNTERS DONE IN ODD HOURS' => 'encounters_done_odd_hours',
        'PASSWORD CHANGES' => 'password_changes'
      }


      def index
        name = TOOLS[parameters.fetch(:name)]

        raise "Tool not found: #{name}" if name.nil?

        render json: eval(name)
      end

      private
      
      def encounters_done_per_provider
        service.encounters_done_per_provider(parameters)
      end      
      
      def password_changes
        service.password_changes(parameters)
      end


      def encounters_done_odd_hours
        service.encounters_done_odd_hours(parameters)
      end
      
      def parameters
        start_date = params[:start_date]
        end_date = params[:end_date]
        program_id = params[:program_id]
        name = params[:name]

        {
          start_date:,
          end_date:,
          program_id:,
          name:
        }
      end

      def service
        DataVerificationService.new
      end
    end
  end
end