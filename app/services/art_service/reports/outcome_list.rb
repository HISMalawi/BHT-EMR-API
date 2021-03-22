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

      def load_report(name)
        name = name.to_sym

        unless REPORTS.include?(name)
          raise "Invalid report: #{name}"
        end

        method(name).call
      end

      def transfer_out
        return outcome_query 2
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
