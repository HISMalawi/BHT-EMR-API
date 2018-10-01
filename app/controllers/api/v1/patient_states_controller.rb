class Api::V1::PatientStatesController < ApplicationController
  def index
    patient_id = params.require %i[patient_id]

    states = PatientState.joins(:patient_program).where(
      'patient_program.patient_id = ?', patient_id
    )
    render json: paginate(states)
  end

  def create
    pprogram_id, state_id = params.require %i[patient_program_id state]

    pprogram = PatientProgram.find pprogram_id
    state = PatientState.find state_id

    ppstate = PatientState.create patient_program_id: pprogram.patient_program_id,
                                  state: state.patient_state_id
    if ppstate.errors.empty?
      render json: ppstate, status: :created
    else
      render json: ppstate.errors, status: :bad_request
    end
  end

  def show
    render json: PatientState.find(params[:id])
  end

  def update
    # TODO: Implement me... Should we be updating state only or maybe also
    #       allow patient_program update?
    render json: { errors: ['UPDATE not implemented'] }, status: :not_found
  end

  def destroy
    ppstate = PatientState.find(params[:id])
    if ppstate.destroy
      render status: :no_content
    else
      render json: { errors: ['Delete failed', ppstate.errors] },
             status: :internal_server_error
    end
  end

  private

  def patient_state(params)
    workflow_exists = ProgramWorkflowState.where(
      program_workflow_state_id: params[:state_id]
    ).exists?

    return params[:state_id] if workflow_exists

    render json: { errors: ['Program state not found'] },
           status: :bad_request
    nil
  end
end
