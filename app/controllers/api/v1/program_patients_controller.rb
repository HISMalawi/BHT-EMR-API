class Api::V1::ProgramPatientsController < ApplicationController
  def show
    render json: service.patient(params[:id])
  end

  def last_drugs_received
    render json: service.patient_last_drugs_received(patient)
  end

  def find_dosages
    service = RegimenService.new(program_id: params[:program_id])
    dosage = service.find_dosages patient, (params[:date]&.to_date || Date.today)
    render json: dosage
  end

  def status
    status = service.find_status patient, (params[:date]&.to_date || Date.today)
    render json: status
  end

  protected

  def service
    ProgramPatientsService.new program: program
  end

  def program
    Program.find(params[:program_id])
  end

  def patient
    Patient.find(params[:program_patient_id])
  end
end
