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

  def destroy
    state = PatientState.find(params[:id])
    reason = params[:reason] || "Voided by #{User.current.username}"
    # state.void(reason)
    service.void_state(state, reason)
    render status: :no_content
  end
  # TODO: Implement show, and maybe update...

  def patient_state
    patient_id, program_id = params.require %i[patient_id program_id]
    state = service.find_patient_state Program.find(program_id), Patient.find(patient_id)
    render json: state
  end

  def close_current_outcome
    date = params[:date]&.to_date || Date.today
    patient_program = PatientProgram.where(program: program, patient: patient)\
                                    .where('DATE(date_enrolled) <= ?', date)\
                                    .last
    patient_state = PatientState.where(patient_program: patient_program)\
                .where('start_date <= ? AND end_date IS NULL', date)\
                .last
    patient_state.end_date = date
    patient_state.save
    render json: patient_state
    #patient_state = service.close_patient_state program patient status date
  end

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
