class Api::V1::LabRemaindersController < ApplicationController

  def index
    render json: service.vl_reminder_info
  end


  private

  def service
    ARTService::VLReminder.new(patient_id: params[:program_patient_id], 
      date: params[:date])
  end

end
