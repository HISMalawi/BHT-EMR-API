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
        query.map(&:patient_id)
      end

      def query
        Patient.find_by_sql <<~SQL
          SELECT patient_program.patient_id
          FROM patient_program
          INNER JOIN patient_state
            ON patient_state.patient_program_id = patient_program.patient_program_id
            AND patient_state.state = 7
            AND patient_state.voided = 0
          INNER JOIN (
            SELECT patient_program.patient_program_id,
                   MAX(patient_state.start_date) AS start_date
            FROM patient_program
            INNER JOIN program
              ON program.program_id = patient_program.program_id
              AND program.name = 'HIV Program'
              AND program.retired = 0
            INNER JOIN patient_state
              ON patient_state.patient_program_id = patient_program.patient_program_id
              AND patient_state.voided = 0
              AND patient_state.start_date < DATE(#{ActiveRecord::Base.connection.quote(end_date)}) + INTERVAL 1 DAY
            WHERE patient_program.voided = 0
            GROUP BY patient_state.patient_program_id
          ) AS latest_patient_state
            ON latest_patient_state.patient_program_id = patient_program.patient_program_id
            AND latest_patient_state.start_date = patient_state.start_date
        SQL
      end
    end
  end
end
