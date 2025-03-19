# frozen_string_literal: true

module Api
  module V1
    class ProgramAppointmentsController < ApplicationController
      def booked_appointments
        program_id = params[:program_id]
        site_id = params[:site_id]
        date = params[:date]&.to_date || Date.today
        render json: service.booked_appointments(program_id, date, site_id)
      end

      def scheduled_appointments
        program_id = params[:program_id].to_i
        date = params[:date]&.to_date || Date.today
        site_id = params[:site_id]

        render json: service.scheduled_appointments(program_id, date, site_id)
      end

      private

      def service
        ProgramAppointmentService
      end
    end
  end
end
