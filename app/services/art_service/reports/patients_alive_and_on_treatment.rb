# frozen_string_literal: true

module ARTService
  module Reports
    # Returns all patients alive and on treatment within a given
    # time period (Tx Curr).
    class PatientsAliveAndOnTreatment
      attr_accessor :start_date, :end_date

      def initialize(start_date:, end_date:, **_kwargs)
        @start_date = start_date
        @end_date = end_date
      end

      def find_report
        PatientState.joins(:patient_program)
                    .where(patient_program: { program_id: HIV_PROGRAM_ID },
                           state: ON_ANTIRETROVIRALS)
                    .where('start_date <= ? AND end_date >= ?', start_date, end_date)
                    .where.not(patient_program: { patient_id: patients_with_terminal_states })
                    .select(:patient_id)
                    .map(&:patient_id)
      end

      private

      HIV_PROGRAM_ID = 1
      ON_ANTIRETROVIRALS = 7
      DEFAULTED = 12
      DIED = 3
      TRANSFERRED_OUT = 2
      TREATMENT_STOPPED = 6

      TERMINAL_STATES = [DEFAULTED, DIED, TRANSFERRED_OUT, TREATMENT_STOPPED].freeze

      def patients_with_terminal_states
        PatientState.joins(:patient_program)
                    .where(patient_program: { program_id: HIV_PROGRAM_ID },
                           state: TERMINAL_STATES)
                    .where('start_date <= ? AND end_date >= ?', start_date, end_date)
                    .group('patient_program.patient_id')
                    .select(:patient_id)
      end
    end
  end
end
