# frozen_string_literal: true

module AppointmentService
  class << self
    include ModelUtils

    def appointment(id)
      encounter_type_id = encounter_type('APPOINTMENT').encounter_type_id
      Encounters.find_by encounter_id: id,
                         encounter_type: encounter_type_id
    end

    def appointments(filters = {})
      Encounter.joins(:type)\
               .where(filters)\
               .where('encounter_type.name = ?', 'APPOINTMENT')\
               .order(date_created: :desc)
    end

    def create_appointment(patient, date)
      Encounter.create type: encounter_type('APPOINTMENT'),
                       patient: patient,
                       encounter_datetime: Time.now,
                       location_id: Location.current.location_id,
                       provider: User.current,
                       observations: [make_appointment_date(patient, date)]
    end

    private

    def make_appointment_date(patient, date)
      Observation.new concept: concept('Appointment date'),
                      value_datetime: date,
                      person: patient.person,
                      obs_datetime: Time.now
    end
  end
end
