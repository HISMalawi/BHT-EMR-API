class Api::V1::AppointmentsController < ApplicationController
  def show
    appointment = AppointmentService.appointment params[:id]
    if appointment
      render json: appointment
    else
      render json: { errors: "Appointment ##{params[:id]} not found" },
             status: :not_found
    end
  end

  def index
    filters = params.permit %i[patient_id encounter_datetime]
    appointments = AppointmentService.appointments filters
    render json: paginate(appointments)
  end

  def create
    patient = Patient.find params.require(%i[patient_id])[0]
    date = parse_date params.require(%i[date])[0]

    return unless date

    appointment = AppointmentService.create_appointment patient, date
    if appointment.errors.empty?
      render json: appointment, status: :created
    else
      logger.error "Failed to create appointment: #{appointment.errors.as_json}"
      render json: appointment.errors, status: :internal_server_error
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
end
