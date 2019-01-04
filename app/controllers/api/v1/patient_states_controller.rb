class Api::V1::PatientStatesController < ApplicationController
  def index
    date = params[:date]&.to_date || Date.today
    states = service.all_patient_states program, patient, date
    render json: states
  end

  def create
    state, = params.require %i[state]
    date = params[:date]&.to_date || Date.today
    patient_state = service.create_patient_state program, patient, state, date
    render json: patient_state, status: :created
  end

  # TODO: Implement show, destroy and maybe update...

  private

  def program
    Program.find(params[:program_id])
  end

  def patient
    Patient.find(params[:program_patient_id])
  end

  def service
    PatientStateService.new
  end
end
