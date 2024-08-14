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

      def booked_patient_appointment
        program_id = params[:program_id]
        patient_id = params[:patient_id]

        render json: service.booked_patient_appointment(program_id, patient_id)
      end

      private

      def service
        ProgramAppointmentService
      end
    end
  end
end
