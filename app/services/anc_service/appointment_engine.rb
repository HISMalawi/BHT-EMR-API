# frozen_string_literal: true

require 'logger'

module ANCService
class AppointmentEngine
  include ModelUtils

  LOGGER = Logger.new STDOUT

  def initialize(program:, patient:, retro_date: Date.today)
    @ref_date = retro_date.respond_to?(:to_date) ? retro_date.to_date : date
    @program = program
    @patient = patient
  end

  def next_appointment_date

    appointment_date = @ref_date + 1.month

    {
      drugs_run_out_date: "",
      appointment_date: appointment_date
    }
  end

  def appointment_encounter(patient, visit_date)
    encounter = Encounter.find_by patient_id: patient.patient_id,
                                  encounter_datetime: visit_date

    return encounter if encounter

    Encounter.new type: encounter_type('APPOINTMENT'),
                  patient: patient,
                  encounter_datetime: Time.now,
                  program: @program,
                  location_id: Location.current.location_id,
                  provider: User.current.person
  end

end

end