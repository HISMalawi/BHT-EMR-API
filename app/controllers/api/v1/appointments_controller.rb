class Api::V1::AppointmentsController < ApplicationController
  include ModelUtils

  def show
    appointment = Encounter.find params[:id]
    render json: appointment
  end

  def index
    encounters = encounter.joins(:type).where(
      'type.name = ?', 'APPOINTMENT'
    ).order(date_created: :desc)

    render json: paginate(encounters)
  end

  def create
    patient_id, date = params.require %i[patient_id date]

    begin
      date = Date.strptime(date)
      patient = Patient.find patient_id
    rescue ArgumentError => e
      return render json: { errors: [e.to_s] }, status: :bad_request
    end

    appointment = Encounter.new type: encounter_type('APPOINTMENT'),
                                patient: patient,
                                encounter_datetime: Time.now,
                                location_id: Location.current.location_id,
                                provider: User.current
    obs = Observation.new concept: concept('Appointment date'),
                          value_datetime: date,
                          person: patient.person,
                          obs_datetime: Time.now

    appointment.observations << obs
    saved = appointment.save

    if saved
      render json: appointment, status: :created
    else
      logger.debug "Errors: #{obs.errors.as_json}"
      render json: appointment.errors, status: :internal_server_error
    end
  end

  def destroy
    appointment = Encounter.find params[:id]
    appointment.obs.destroy && appointment.destroy
  end
end
