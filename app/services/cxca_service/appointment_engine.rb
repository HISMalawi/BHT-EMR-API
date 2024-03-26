# frozen_string_literal: true

require 'logger'

module CxcaService
  class AppointmentEngine
    include ModelUtils

    LOGGER = Logger.new $stdout

    def initialize(program:, patient:, retro_date: Date.today)
      @ref_date = retro_date.respond_to?(:to_date) ? retro_date.to_date : date
      @program = program
      @patient = patient
    end

    def next_appointment_date
      concept = ConceptName.find_by_name 'HIV status'
      negative_concept = []
      negative_concept << ConceptName.find_by_name('Negative').concept_id
      negative_concept << ConceptName.find_by_name('Undisclosed').concept_id

      ob = Observation.where("concept_id = ? AND person_id = ?
        AND DATE(obs_datetime) <= ?",
                             concept.concept_id, @patient.patient_id, @ref_date.to_date)\
                      .order('obs_datetime DESC, date_created DESC').first

      1.week

      ref_period = if ob.blank?
                     1.year
                   elsif negative_concept.include?(ob.value_coded)
                     3.year
                   else
                     1.year
                   end

      clinic_days = %w[Monday Tuesday Wednesday Thursday Friday]
      appointment_date = @ref_date + ref_period
      valid_day = false

      until valid_day
        if clinic_days.include?(appointment_date.strftime('%A'))
          valid_day = true
        else
          appointment_date -= 1.day
        end
      end

      {
        drugs_run_out_date: '',
        appointment_date:
      }
    end
  end
end
