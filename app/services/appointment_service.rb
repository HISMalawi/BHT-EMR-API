# frozen_string_literal: true

require 'logger'

class AppointmentService
  include ModelUtils

  LOGGER = Logger.new STDOUT

  def initialize(retro_date: Date.today)
    @retro_date = retro_date
  end

  def appointment(id)
    Observation.find_by obs_id: id, concept: concept('Appointment date')
  end

  def appointments(filters = {})
    filters = filters.to_hash.each_with_object({}) do |kv_pair, transformed_hash|
      key, value = kv_pair
      transformed_hash["obs.#{key}"] = value
    end

    appointments = Observation.joins(:concept)\
                              .where(concept: concept('Appointment date'))
    appointments = appointments.where(filters) unless appointments.empty?
    appointments.order(date_created: :desc)
  end

  def create_appointment(patient, date)
    if date < @retro_date
      raise ArgumentError, "Can't set appointment date, #{date}, to date before visit date, #{@retro_date}"
    end

    encounter = appointment_encounter patient, @retro_date
    encounter.observations << make_appointment_date(date)
    unless encounter.save
      LOGGER.error "Failed to create appointment\n\t#{encounter.errors}"
      raise "Failed to create appointment, #{date}"
    end

    encounter
  end

  private

  def make_appointment_date(patient, date)
    Observation.new concept: concept('Appointment date'),
                    value_datetime: date,
                    person: patient.person,
                    obs_datetime: Time.now
  end

  def appointment_encounter(patient, visit_date)
    encounter = Encounter.find_by patient_id: patient.patient_id,
                                  encounter_datetime: visit_date

    return encounter if encounter

    Encounter.new type: encounter_type('APPOINTMENT'),
                  patient: patient,
                  encounter_datetime: Time.now,
                  location_id: Location.current.location_id,
                  provider: User.current
  end
end
