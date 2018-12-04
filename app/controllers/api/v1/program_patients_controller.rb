class Api::V1::ProgramPatientsController < ApplicationController
  before_action :load_engine

  def show
    render json: @engine.patient(params[:id])
  end

  def last_drugs_received
    render json: @engine.patient_last_drugs_received(params[:program_patient_id])
  end

  def find_dosages
    service = RegimenService.new(program_id: params[:program_id])
    dosage = service.find_dosages Patient.find(params[:program_patient_id]),
                                  Date.strptime(params[:date] || Date.today.to_s)
    render json: dosage
  end

  protected

  def load_engine
    @engine = ProgramPatientsService.load_engine params[:program_id]
  end
end
