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
      {
        drugs_run_out_date: "",
        appointment_date: @ref_date + 1.year
      }
    end
  end
end
