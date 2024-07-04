require './app/services/immunization_service/vaccine_schedule_service'

class Api::V1::VaccineScheduleController < ApplicationController
  def vaccine_schedule
    patient = Person.find(immunization_schedule_params[:patient_id].to_i)
    vaccine_schedule = VaccineScheduleService.vaccine_schedule(patient)
    if vaccine_schedule[:error]
      render json: { error: vaccine_schedule[:error] }, status: :unprocessable_entity
    else
      render json: vaccine_schedule, status: :ok
    end
  end

  private

  def immunization_schedule_params
    params.require(:patient_id)
    params.permit(:patient_id)
    {patient_id: params[:patient_id]}
  end
end
