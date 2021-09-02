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
        long_term_defaulters(patients.map { |patient| patient['patient_id'] })
          .each { |defaulter| patients << defaulter }

        patients
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
          SELECT orders.patient_id,
                 patient_identifier.identifier AS filing_number,
                 'Defaulted' AS outcome,
                 current_defaulter_date(orders.patient_id, #{start_date}) AS outcome_date
          FROM orders
          INNER JOIN order_type
            ON order_type.order_type_id = orders.order_type_id
            AND order_type.name = 'Drug order'
            AND order_type.retired = 0
          INNER JOIN drug_order
            ON drug_order.order_id = orders.order_id
            AND drug_order.quantity > 0
          INNER JOIN arv_drug
            ON arv_drug.drug_id = drug_order.drug_inventory_id
          INNER JOIN (
            SELECT orders.patient_id,
                   MAX(auto_expire_date) AS drug_run_out_date
            FROM orders
            INNER JOIN order_type
              ON order_type.order_type_id = orders.order_type_id
              AND order_type.name = 'Drug order'
              AND order_type.retired = 0
            INNER JOIN drug_order
              ON drug_order.order_id = orders.order_id
              AND drug_order.quantity > 0
            INNER JOIN arv_drug
              ON arv_drug.drug_id = drug_order.drug_inventory_id
            WHERE orders.voided = 0
              #{"AND orders.patient_id NOT IN (#{patients_to_exclude.join(',')})" unless patients_to_exclude.empty?}
            GROUP BY orders.patient_id
            LIMIT 100
          ) AS last_patient_drug_order
            ON last_patient_drug_order.patient_id = orders.patient_id
            AND last_patient_drug_order.drug_run_out_date < DATE(#{start_date}) - INTERVAL 6 MONTH
          INNER JOIN patient_identifier
            ON patient_identifier.patient_id = orders.patient_id
            AND patient_identifier.voided = 0
          INNER JOIN patient_identifier_type
            ON patient_identifier_type.patient_identifier_type_id = patient_identifier.identifier_type
            AND patient_identifier_type.name = 'Filing number'
            AND patient_identifier_type.retired = 0
          WHERE orders.voided = 0
          GROUP BY orders.patient_id
          HAVING outcome_date IS NOT NULL
        SQL
      end
    end
  end
end
