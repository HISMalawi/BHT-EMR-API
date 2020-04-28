# frozen_string_literal: true

module ARTService
  module Reports
    Constants = ARTService::Constants

    # Reports on all patients that were on treatment in given time period
    # regardless of whether they have a terminal state or not within the
    # period.
    class PatientsOnTreatment
      attr_reader :start_date, :end_date

      def initialize(start_date:, end_date:)
        @start_date = start_date
        @end_date = end_date
      end

      # Returns patients that were on treatment within the given time period.
      def self.within(start_date, end_date)
        on_arvs = PatientState.where('start_date <= ? AND end_date >= ? AND state = ?',
                                     start_date, end_date, Constants::States::ON_ANTIRETROVIRALS)
                              .group(:patient_program_id)

        PatientProgram.select(:patient_id)
                      .joins(:patient_states)
                      .merge(on_arvs)
                      .where(program_id: Constants::PROGRAM_ID)
      end

      # We an interface to satisfy, let's be good citizens
      def find_report
        within(start_date, end_date).map(&:patient_id)
      end
    end
  end
end
