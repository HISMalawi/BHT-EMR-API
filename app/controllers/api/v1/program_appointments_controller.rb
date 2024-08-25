# frozen_string_literal: true

module Api
  module V1
    class ProgramAppointmentsController < ApplicationController
      def booked_appointments
        program_id = params[:program_id]
        date = params[:date]&.to_date || Date.today
        end_date = params[:end_date]&.to_date || Date.today

        return_data(program_id, date, end_date)
      end

      def scheduled_appointments
        program_id = params[:program_id].to_i
        date = params[:date]&.to_date || Date.today
        end_date = params[:end_date]&.to_date || Date.today

        return_data(program_id, date, end_date)
      end

      private

      def service
        ProgramAppointmentService
      end

      def return_data(program_id, date, end_date)
        if program_id.to_i == Program.find_by_name('Immunization Program').program_id.to_i
          render json: service.booked_appointments(program_id, date, end_date, location_id: User.current.location_id)
        else
          render json: service.booked_appointments(program_id, date)
        end
      end
    end
  end
end
