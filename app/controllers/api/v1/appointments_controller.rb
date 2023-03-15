class Api::V1::AppointmentsController < ApplicationController
  def show
    appointment = appointment_service.appointment params[:id]
    if appointment
      render json: appointment
    else
      render json: { errors: "Appointment ##{params[:id]} not found" },
             status: :not_found
    end
  end

  def index
    filters = params.permit %i[person_id obs_datetime date program_id]
    appointments = appointment_service.appointments filters
    render json: paginate(appointments)
  end

  def create
    patient = Patient.find params.require(%i[patient_id])[0]
    date = parse_date params.require(%i[date])[0]

    return unless date

    appointment = appointment_service.create_appointment patient, date
    if appointment.errors.empty?
      render json: appointment, status: :created
    else
      logger.error "Failed to create appointment: #{appointment.errors.as_json}"
      render json: appointment.errors, status: :internal_server_error
    end
  end

  def next_appointment
    accepted_params = params.permit(%i[patient_id date program_id])
    encounter = Encounter.where('encounter_type = ? AND patient_id = ? AND DATE(encounter_datetime) <= ? AND program_id = ?', EncounterType.find_by_name('APPOINTMENT').id, accepted_params[:patient_id], accepted_params[:date], accepted_params[:program_id])&.last
    obs = encounter ? encounter.observations&.where('concept_id = ?', ConceptName.find_by_name('APPOINTMENT DATE').concept_id)&.last : nil
    if obs
      render json: { appointment_date: obs.value_datetime.strftime('%Y-%m-%d')}
    else
      render json: { errors: 'No appointment found' }, status: :not_found
    end
  end

  def update
    # TODO: Implement me
    render json: { errors: ['Not implemented'] }, status: :not_found
  end

  def destroy
    appointment = Encounter.find params[:id]
    if appointment.obs.destroy && appointment.destroy
      render status: :no_content
    else
      render json: { errors: [appointment.errors, appointment.obs.errors] },
             status: :internal_server_error
    end
  end

  protected

  def appointment_service
    return @appointment_service if @appointment_service

    date = headers['SESSION_DATE'] ? Date.strptime(headers['SESSION_DATE']) : Date.today
    @appointment_service = AppointmentService.new retro_date: date

    @appointment_service
  end
end
