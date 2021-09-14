# frozen_string_literal: true

require 'logger'

module CXCAService
  class AppointmentEngine
    include ModelUtils

    LOGGER = Logger.new STDOUT

    def initialize(program:, patient:, retro_date: Date.today)
      @ref_date = retro_date.respond_to?(:to_date) ? retro_date.to_date : date
      @program = program
      @patient = patient
    end

    def next_appointment_date
      concept = ConceptName.find_by_name 'Directly observed treatment option'
      ob = Observation.where("concept_id = ? AND person_id = ? AND DATE(obs_datetime)=?",
       concept.concept_id, @patient.patient_id, @ref_date.to_date)
      ref_period = ob.blank? ? 1.year : 1.week

      {
        drugs_run_out_date: "",
        appointment_date: @ref_date + ref_period
      }
    end
  end
end
