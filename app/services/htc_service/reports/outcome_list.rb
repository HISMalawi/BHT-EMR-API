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
        outcome_query 'Patient transferred out'
      end

      def died
        return outcome_query 'Patient died'
      end

      def stopped
        return outcome_query 'Treatment stopped'
      end

      def outcome_query(outcome_state)
=begin
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
=end

        report_type = 'moh'
        cohort_list = ARTService::Reports::CohortBuilder.new(outcomes_definition: report_type)
        cohort_list.create_tmp_patient_table
        cohort_list.load_data_into_temp_earliest_start_date(@end_date.to_date)

        outcomes = ARTService::Reports::Cohort::Outcomes.new(end_date: @end_date.to_date, definition: report_type)
        outcomes.update_cummulative_outcomes

        transfer_out_to_location_sql = ""
        transfer_out_to_location_name_sql = ""
        if outcome_state.match(/Transfer/i)
          concept_id = ConceptName.find_by_name('Transfer out to location').concept_id
          transfer_out_to_location_name_sql = " ,l.name transferred_out_to"
          transfer_out_to_location_sql = " LEFT JOIN obs to_location ON to_location.person_id = e.patient_id"
          transfer_out_to_location_sql += " AND to_location.concept_id = #{concept_id} AND to_location.voided = 0"
          transfer_out_to_location_sql += " LEFT JOIN location l ON l.location_id = to_location.value_numeric"
        end

        data = ActiveRecord::Base.connection.select_all <<~SQL
          SELECT
            e.patient_id, i.identifier, e.birthdate,
            e.gender, n.given_name, n.family_name,
            art_reason.name art_reason, a.value cell_number,
            s3.state_province district, s3.county_district ta,
            s3.city_village village, TIMESTAMPDIFF(year, DATE(e.birthdate), DATE('#{@end_date}')) age,
            pp.date_enrolled, pp.date_completed,
            s2.start_date outcome_date, s2.end_date, s2.state
            #{transfer_out_to_location_name_sql}
          FROM temp_earliest_start_date e
          INNER JOIN temp_patient_outcomes o ON e.patient_id = o.patient_id
          LEFT JOIN patient_identifier i ON i.patient_id = e.patient_id
          AND i.voided = 0 AND i.identifier_type = 4
          INNER JOIN person_name n ON n.person_id = e.patient_id AND n.voided = 0
          LEFT JOIN person_attribute a ON a.person_id = e.patient_id
          AND a.voided = 0 AND a.person_attribute_type_id = 12
          LEFT JOIN person_address s3 ON s3.person_id = e.patient_id
          LEFT JOIN concept_name art_reason ON art_reason.concept_id = e.reason_for_starting_art
          #{transfer_out_to_location_sql}
          INNER JOIN patient_program pp ON pp.patient_id = e.patient_id AND pp.program_id = 1
          INNER JOIN patient_state s2 ON s2.patient_program_id = pp.patient_program_id
          INNER JOIN program_workflow_state ws ON ws.program_workflow_state_id = s2.state
          INNER JOIN program_workflow w ON w.program_workflow_id = ws.program_workflow_id
          INNER JOIN concept_name n2 ON n2.concept_id = ws.concept_id
          WHERE o.cum_outcome = '#{outcome_state}'
          AND pp.voided = 0 AND s2.voided = 0 AND s2.start_date
          BETWEEN '#{@start_date}' AND '#{@end_date}' AND s2.state NOT IN(7,1, 12)
          GROUP BY e.patient_id ORDER BY e.patient_id, n.date_created DESC;
        SQL

        patients = []

        (data || []).each do |person|


          patients << {
            patient_id: person["patient_id"],
            given_name: person['given_name'],
            family_name: person['family_name'],
            birthdate: person['birthdate'],
            gender: person['gender'],
            arv_number: person['arv_number'],
            outcome: 'Defaulted',
            art_reason: person['art_reason'],
            cell_number: person['cell_number'],
            district: person['district'],
            ta: person['ta'],
            village: person['village'],
            current_age: person['age'],
            identifier: person['identifier'],
            transferred_out_to: (person['transferred_out_to'] ? person['transferred_out_to'] : 'N/A'),
            outcome_date: (person['outcome_date']&.to_date || 'N/A')
          }
        end

        return patients
      end

    end
  end
end
