# frozen_string_literal: true

module Api
  module V1
    class ImmunizationReportsController < ApplicationController
      before_action :validate_params
      def index
        report = service.generate_report(name: @name,
                                         type: @name,
                                         start_date: @start_date,
                                         end_date: @end_date,
                                         quarter: @quarter,
                                         year: @year)

        if report
          render json: report
        else
          render status: :no_content
        end
      end

      private

      def validate_params
        required_params = %i[start_date end_date name]
        missing_params = required_params.select { |param| params[param].blank? }
        
        unless missing_params.empty?
          handle_errors "Missing required parameters: #{missing_params.join(', ')}", missing_params
          return
        end
        
        permitted = params.permit(:start_date, :end_date, :name, :quarter, :year).to_h
        @start_date, @end_date, @name, @quarter, @year = permitted.values_at(:start_date, :end_date, :name, :quarter, :year)
        
        if @start_date.present? && @end_date.present?
          handle_errors 'Start date cannot be greater than end date', 'start_date' if @start_date > @end_date
          handle_errors 'End date cannot be greater than today', 'end_date' if @end_date.to_date > Date.today
        end
        
        handle_errors 'Name cannot be blank', 'name' if @name.blank?
      end
      
      def handle_errors(message, field)
        # Define your error handling logic here, e.g., rendering JSON with errors or raising exceptions
        render json: { error: message, field: field }, status: :unprocessable_entity
      end
      

      def handle_errors(message, entity)
        error = UnprocessableEntityError.new(message)
        error.add_entity(entity)
        raise error
      end

      def service
        ReportService.new(program_id: 33, overwrite_mode: false)
      end
    end
  end
end
