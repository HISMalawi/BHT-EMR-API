class Api::V1::ProgramPatientsController < ApplicationController
  def show
    render json: service.patient(params[:id])
  end

  def last_drugs_received
    render json: service.patient_last_drugs_received(params[:program_patient_id])
  end

  def find_dosages
    service = RegimenService.new(program_id: params[:program_id])
    dosage = service.find_dosages Patient.find(params[:program_patient_id]),
                                  Date.strptime(params[:date] || Date.today.to_s)
    render json: dosage
  end

  def status
    status = service.find_status(Patient.find(params[:program_patient_id]),
                                 Date.strptime(params[:date] || Date.today.to_s))
    render json: status
  end

  protected

  def service
    ProgramPatientsService.load_engine params[:program_id]
  end
end
