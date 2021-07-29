# frozen_string_literal: true

module ARTService
  module Reports
    class OutcomeList

      REPORTS = Set.new(%i[transfer_out died stopped]).freeze

      def initialize(start_date:, end_date:, outcome:)
        @start_date = start_date.to_date.strftime("%Y-%m-%d 00:00:00")
        @end_date = end_date.to_date.strftime("%Y-%m-%d 23:59:59")
        @report = load_report outcome.downcase.split(" ").join("_")
      end

      def get_list
        return @report
      end

      private

      def start_date
        ActiveRecord::Base.connection.quote(@start_date)
      end

      def end_date
        ActiveRecord::Base.connection.quote(@end_date)
      end

      def load_report(name)
        name = name.to_sym

        unless REPORTS.include?(name)
          raise "Invalid report: #{name}"
        end

        method(name).call
      end

      def transfer_out
        ActiveRecord::Base.connection.select_all <<~SQL
          SELECT patient_program.patient_id,
                 arv_number.identifier,
                 patient_program.date_enrolled,
                 patient_program.date_completed,
                 patient_state.start_date,
                 patient_state.end_date,
                 patient_state.state,
                 state_concept.name,
                 person_name.given_name,
                 person_name.family_name,
                 person.gender,
                 person.birthdate,
                 transfer_out_to_obs.value_text AS transferred_out_to
          FROM patient_program
          INNER JOIN program
            ON program.program_id = patient_program.program_id
            AND program.name = 'HIV Program'
            AND program.retired = 0
          INNER JOIN patient_state
            ON patient_state.patient_program_id = patient_program.patient_program_id
            AND patient_state.start_date >= DATE(#{start_date})
            AND patient_state.start_date < DATE(#{end_date}) + INTERVAL 1 DAY
            AND patient_state.voided = 0
          INNER JOIN program_workflow_state
            ON program_workflow_state.program_workflow_state_id = patient_state.state
          INNER JOIN concept_name AS state_concept
            ON state_concept.concept_id = program_workflow_state.concept_id
            AND state_concept.name = 'Patient transferred out'
            AND state_concept.voided = 0
          LEFT JOIN person_name
            ON person_name.person_id = patient_program.patient_id
            AND person_name.voided = 0
          INNER JOIN person
            ON person.person_id = patient_program.patient_id
            AND person.voided = 0
          LEFT JOIN patient_identifier AS arv_number
            ON arv_number.patient_id = patient_program.patient_id
            AND arv_number.voided = 0
          LEFT JOIN patient_identifier_type
            ON patient_identifier_type.patient_identifier_type_id = arv_number.identifier_type
            AND patient_identifier_type.name = 'ARV Number'
            AND patient_identifier_type.retired = 0
          LEFT JOIN encounter AS exit_from_care_encounter
            ON exit_from_care_encounter.patient_id = patient_program.patient_id
            AND exit_from_care_encounter.encounter_datetime >= DATE(patient_state.start_date)
            AND exit_from_care_encounter.encounter_datetime < DATE(patient_state.start_date) + INTERVAL 1 DAY
            AND exit_from_care_encounter.encounter_type IN (SELECT encounter_type_id FROM encounter_type WHERE name = 'EXIT FROM HIV CARE')
            AND exit_from_care_encounter.voided = 0
          LEFT JOIN obs AS transfer_out_to_obs
            ON transfer_out_to_obs.encounter_id = exit_from_care_encounter.encounter_id
            AND exit_from_care_encounter.encounter_id IS NOT NULL
            AND transfer_out_to_obs.voided = 0
          LEFT JOIN concept_name AS transfer_out_to_concept
            ON transfer_out_to_concept.concept_id = transfer_out_to_obs.concept_id
            AND transfer_out_to_concept.name = 'Transfer out site'
            AND transfer_out_to_concept.voided = 0
          GROUP BY patient_program.patient_id
          ORDER BY patient_state.start_date DESC, person_name.date_created DESC;
        SQL
      end

      def died
        return outcome_query 3
      end

      def stopped
        return outcome_query 6
      end

      def outcome_query(outcome_state)
        data = ActiveRecord::Base.connection.select_all <<~SQL
        SELECT
          pp.patient_id, i.identifier, pp.date_enrolled, pp.date_completed,
          s.start_date, s.end_date, s.state, n.name,
          fn.given_name, fn.family_name, p.gender, p.birthdate
        FROM  program
        INNER JOIN patient_program pp ON program.program_id = pp.program_id AND program.program_id = 1
        INNER JOIN patient_state s ON s.patient_program_id = pp.patient_program_id
        INNER JOIN program_workflow_state ws ON ws.program_workflow_state_id = s.state
        INNER JOIN program_workflow w ON w.program_workflow_id = ws.program_workflow_id
        INNER JOIN concept_name n ON n.concept_id = ws.concept_id
        LEFT JOIN person_name fn ON fn.person_id = pp.patient_id AND fn.voided = 0
        INNER JOIN person p ON p.person_id = pp.patient_id AND p.voided = 0
        LEFT JOIN patient_identifier i ON i.patient_id = pp.patient_id AND i.voided = 0 AND i.identifier_type = 4
        WHERE pp.voided = 0 AND s.voided = 0 AND s.start_date BETWEEN '#{@start_date}' AND '#{@end_date}'
        AND s.state NOT IN(7,1, 12) AND s.state = #{outcome_state}
        GROUP BY pp.patient_id ORDER BY s.start_date DESC, fn.date_created DESC;
        SQL

        return data
      end

    end
  end
end
