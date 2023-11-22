# frozen_string_literal: true

module Api
  module V1
    class ProgramAppointmentsController < ApplicationController
      def booked_appointments
        program_id = params[:program_id]
        date = params[:date]&.to_date || Date.today

        render json: service.booked_appointments(program_id, date)
      end

      def scheduled_appointments
        program_id = params[:program_id].to_i
        date = params[:date]&.to_date || Date.today

        render json: service.scheduled_appointments(program_id, date)
      end

      private

      def service
        ProgramAppointmentService
      end
    end
  end
end
