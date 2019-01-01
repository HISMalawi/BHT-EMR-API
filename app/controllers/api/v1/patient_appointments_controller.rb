# frozen_string_literal: true

class Api::V1::PatientAppointmentsController < ApplicationController
  def next_appointment_date
    patient = Patient.find params[:patient_id]
    date = params[:date] ? Date.strptime(params[:date]) : Date.today

    appointment_service = AppointmentService.new
    appointment_date = appointment_service.next_appointment_date patient, date
    if appointment_date
      render json: appointment_date
    else
      render status: :not_found
    end
  end
end
