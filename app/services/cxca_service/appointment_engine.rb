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
      concept = ConceptName.find_by_name 'HIV status'
      negative_concept = ConceptName.find_by_name 'Negative'

      ob = Observation.where("concept_id = ? AND person_id = ?
        AND DATE(obs_datetime) <= ?",
       concept.concept_id, @patient.patient_id, @ref_date.to_date).\
       order("obs_datetime DESC, date_created DESC").first

      ref_period = 1.week

      unless ob.blank?
        if ob.value_coded == negative_concept.concept_id
          ref_period = 3.year
        end
      else
        ref_period = 1.year
      end

      clinic_days =  ['Monday','Tuesday','Wednesday','Thursday','Friday']
      appointment_date = @ref_date + ref_period
      valid_day = false

      while !valid_day do
        if clinic_days.include?(appointment_date.strftime('%A'))
          valid_day = true
        else
          appointment_date -= 1.day
        end
      end


      {
        drugs_run_out_date: "",
        appointment_date: appointment_date
      }
    end
  end
end
