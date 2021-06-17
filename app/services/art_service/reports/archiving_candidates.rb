# frozen_string_literal: true

##
# Returns all patients with active filing numbers that are suitable for archival
module ARTService
  module Reports
    class ArchivingCandidates
      def initialize(start_date: nil, **_kwargs)
        @start_date = start_date || Date.today
      end

      def find_report
        patients = patients_with_adverse_outcomes.to_a
        defaulters = long_term_defaulters(patients.map { |patient| patient['patient_id'] })

        defaulters.each { |defaulter| patients << defaulter }
        not_on_treatment
      end

      private

      def start_date
        ActiveRecord::Base.connection.quote(@start_date)
      end

      def patients_with_adverse_outcomes
        ActiveRecord::Base.connection.select_all <<~SQL
          SELECT patient_program.patient_id,
                 patient_identifier.identifier AS filing_number,
                 concept_name.name AS outcome,
                 patient_state.start_date AS outcome_date
          FROM patient_program
          INNER JOIN program
            ON program.program_id = patient_program.program_id
            AND program.name = 'HIV Program'
          INNER JOIN patient_state
            ON patient_state.patient_program_id = patient_program.patient_program_id
          INNER JOIN program_workflow
            ON program_workflow.program_id = patient_program.program_id
            AND program_workflow.retired = 0
          INNER JOIN program_workflow_state
            ON program_workflow_state.program_workflow_state_id = patient_state.state
            AND program_workflow_state.program_workflow_id = program_workflow.program_workflow_id
            AND program_workflow_state.retired = 0
          INNER JOIN concept_name
            ON concept_name.concept_id = program_workflow_state.concept_id
            AND concept_name.name IN ('Patient died', 'Patient transferred out', 'Treatment stopped')
            AND concept_name.voided = 0
          INNER JOIN (
            SELECT patient_program.patient_program_id,
                   MAX(patient_state.start_date) AS outcome_date
            FROM patient_state
            INNER JOIN patient_program
              ON patient_program.patient_program_id = patient_state.patient_program_id
              AND patient_program.voided = 0
            INNER JOIN program
              ON program.program_id = patient_program.program_id
              AND program.name = 'HIV Program'
              AND program.retired = 0
            WHERE patient_state.voided = 0
              AND patient_state.start_date < DATE(#{start_date}) + INTERVAL 1 DAY
            GROUP BY patient_program.patient_id
          ) AS latest_outcome
            ON latest_outcome.patient_program_id = patient_state.patient_program_id
            AND latest_outcome.outcome_date = patient_state.start_date
          INNER JOIN patient_identifier
            ON patient_identifier.patient_id = patient_program.patient_id
            AND patient_identifier.voided = 0
          INNER JOIN patient_identifier_type
            ON patient_identifier_type.patient_identifier_type_id = patient_identifier.identifier_type
            AND patient_identifier_type.name = 'Filing number'
            AND patient_identifier_type.retired = 0
          WHERE patient_program.voided = 0
          GROUP BY patient_program.patient_id
        SQL
      end

      ##
      # Returns all patients that haven't been seen in the last 6 months
      # and are defaulters
      def long_term_defaulters(patients_to_exclude = [])
        ActiveRecord::Base.connection.select_all <<~SQL
          SELECT encounter.patient_id,
                 patient_identifier.identifier AS filing_number,
                 'Defaulted' AS outcome,
                 current_defaulter_date(encounter.patient_id, #{start_date}) AS outcome_date
          FROM encounter
          INNER JOIN program
            ON program.program_id = encounter.program_id
            AND program.name = 'HIV Program'
            AND program.retired = 0
          INNER JOIN patient_identifier
            ON patient_identifier.patient_id = encounter.patient_id
            AND patient_identifier.voided = 0
          INNER JOIN patient_identifier_type
            ON patient_identifier_type.patient_identifier_type_id = patient_identifier.identifier_type
            AND patient_identifier_type.name = 'Filing number'
            AND patient_identifier_type.retired = 0
          WHERE encounter.voided = 0
            AND encounter.encounter_datetime <= DATE(#{start_date}) - INTERVAL 6 MONTH
            AND (encounter.patient_id NOT IN (#{patients_to_exclude.join(',')})
                 OR encounter.patient_id NOT IN (
                    SELECT patient_program.patient_id
                    FROM patient_program
                    INNER JOIN program
                      ON program.program_id = patient_program.program_id
                      AND program.name = 'HIV Program'
                      AND program.retired = 0
                    INNER JOIN encounter
                      ON encounter.program_id = patient_program.program_id
                      AND encounter.patient_id = patient_program.patient_id
                      AND encounter.encounter_datetime >= DATE(#{start_date}) - INTERVAL 6 MONTH
                      AND encounter.voided = 0
                    INNER JOIN encounter_type
                      ON encounter_type.encounter_type_id = encounter.encounter_type
                      AND encounter_type.name = 'HIV Reception'
                      AND encounter_type.retired = 0
                    WHERE patient_program.voided = 0
                    GROUP BY patient_program.patient_id
                ))
          GROUP BY encounter.patient_id
          HAVING outcome_date IS NOT NULL
          LIMIT 10
        SQL
      end
    end
  end
end
