require './app/services/immunization_service/vaccine_schedule_service'

class Api::V1::VaccineScheduleController < ApplicationController
  def vaccine_schedule
    patient = Person.find(immunization_schedule_params[:patient_id].to_i)
    vaccine_schedule = VaccineScheduleService.vaccine_schedule(patient)
    render json: vaccine_schedule, status: :ok
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def immunization_schedule_params
    params.require(:patient_id)
    params.permit(:patient_id)
    {patient_id: params[:patient_id]}
  end
end
