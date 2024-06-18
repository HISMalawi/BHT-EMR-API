# frozen_string_literal: true

module ArtService
  module Reports
    # Cohort report builder class.
    #
    # This class only provides one public method (start_build_report) besides
    # the constructor. This method must be called to build report and save
    # it to database.
    class ArtCohort
      include ConcurrencyUtils
      include ModelUtils

      LOCK_FILE = 'art_service/reports/cohort.lock'

      def initialize(name:, type:, start_date:, end_date:, **kwargs)
        @name = name
        @start_date = start_date
        @end_date = end_date
        @type = type
        @cohort_builder = CohortBuilder.new
        @cohort_struct = CohortStruct.new
        @occupation = kwargs[:occupation]
      end

      def build_report
        with_lock(LOCK_FILE, blocking: false) do
          @cohort_builder.build(@cohort_struct, @start_date, @end_date, @occupation)
          clear_drill_down
          save_report
        end
      rescue FailedToAcquireLock => e
        Rails.logger.warn("ART#Cohort report is locked by another process: #{e}")
      end

      def find_report
        Report.where(type: @type, name: "#{@name} #{@occupation}",
                     start_date: @start_date, end_date: @end_date)\
              .order(date_created: :desc)\
              .first
      end

      def defaulter_list(pepfar)
        report_type = (pepfar ? 'pepfar' : 'moh')
        defaulter_date_sql = pepfar ? 'current_pepfar_defaulter_date' : 'current_defaulter_date'
        ArtService::Reports::CohortBuilder.new(outcomes_definition: report_type)
                                          .init_temporary_tables(@start_date, @end_date, @occupation)

        ActiveRecord::Base.connection.select_all <<~SQL
          SELECT
            e.patient_id person_id, i.identifier arv_number, e.birthdate,
            e.gender, n.given_name, n.family_name,
            art_reason.name art_reason, a.value cell_number, landmark.value landmark,
            s.state_province district, s.county_district ta,
            s.city_village village, TIMESTAMPDIFF(year, DATE(e.birthdate), DATE('#{@end_date}')) age,
            #{defaulter_date_sql}(e.patient_id, TIMESTAMP('#{@end_date.to_date.strftime('%Y-%m-%d 23:59:59')}')) AS defaulter_date,
            DATE(appointment.appointment_date) AS appointment_date
          FROM temp_earliest_start_date e
          INNER JOIN temp_patient_outcomes o ON e.patient_id = o.patient_id
          INNER JOIN (
            SELECT e.patient_id, MAX(o.value_datetime) appointment_date
            FROM encounter e
            INNER JOIN obs o ON o.encounter_id = e.encounter_id AND o.voided = 0 AND o.concept_id = 5096 -- appointment date
            WHERE e.encounter_type = 7 -- appointment encounter type
            AND e.program_id = 1 -- hiv program
            AND e.patient_id IN (SELECT patient_id FROM temp_patient_outcomes WHERE cum_outcome = 'Defaulted')
            AND e.encounter_datetime < DATE('#{@end_date}') + INTERVAL 1 DAY
            GROUP BY e.patient_id
          ) appointment ON appointment.patient_id = e.patient_id
          LEFT JOIN patient_identifier i ON i.patient_id = e.patient_id AND i.voided = 0 AND i.identifier_type = 4
          INNER JOIN person_name n ON n.person_id = e.patient_id AND n.voided = 0
          LEFT JOIN person_attribute a ON a.person_id = e.patient_id AND a.voided = 0 AND a.person_attribute_type_id = 12
          LEFT JOIN person_attribute landmark ON landmark.person_id = e.patient_id AND landmark.voided = 0 AND landmark.person_attribute_type_id = 19
          LEFT JOIN person_address s ON s.person_id = e.patient_id AND s.voided = 0
          LEFT JOIN concept_name art_reason ON art_reason.concept_id = e.reason_for_starting_art AND art_reason.voided = 0
          WHERE o.cum_outcome = 'Defaulted'
          GROUP BY e.patient_id
          HAVING (defaulter_date >= DATE('#{@start_date}') AND defaulter_date <= DATE('#{@end_date}')) OR (defaulter_date IS NULL)
          ORDER BY e.patient_id, n.date_created DESC;
        SQL
      end

      def cohort_report_drill_down(id)
        id = ActiveRecord::Base.connection.quote(id)

        patients = ActiveRecord::Base.connection.select_all <<~SQL
          SELECT i.identifier arv_number, p.birthdate,
                 p.gender, n.given_name, n.family_name, p.person_id patient_id,
                 outcomes.cum_outcome AS outcome
          FROM person p
          INNER JOIN cohort_drill_down c ON c.patient_id = p.person_id
          INNER JOIN temp_patient_outcomes AS outcomes
            ON outcomes.patient_id = c.patient_id
          LEFT JOIN patient_identifier i ON i.patient_id = p.person_id
          AND i.voided = 0 AND i.identifier_type = 4
          LEFT JOIN person_name n ON n.person_id = p.person_id AND n.voided = 0
          WHERE c.reporting_report_design_resource_id = #{id}
          GROUP BY p.person_id ORDER BY p.person_id, p.date_created;
        SQL

        patients.map do |person|
          {
            person_id: person['patient_id'],
            given_name: person['given_name'],
            family_name: person['family_name'],
            birthdate: person['birthdate'],
            gender: person['gender'],
            arv_number: person['arv_number'],
            outcome: person['outcome']
          }
        end
      end

      private

      LOGGER = Rails.logger

      def find_saved_report
        @report = Report.where(type: @type, name: "#{@name} #{@occupation}",
                              start_date: @start_date, end_date: @end_date)
        @report&.map { |r| r['id'] } || []
      end

      # Writes the report to database
      def save_report
        Report.transaction do
          report = Report.create(name: "#{@name} #{@occupation}",
                                 start_date: @start_date,
                                 end_date: @end_date,
                                 type: @type,
                                 creator: User.current.id,
                                 renderer_type: 'PDF')

          values = save_report_values(report)

          { report:, values: }
        end
      end

      # Writes the report values to database
      def save_report_values(report)
        @cohort_struct.values.collect do |value|
          puts "Saving #{value.name} = #{value_contents_to_json(value.contents)}"
          report_value = ReportValue.create(report:,
                                            name: value.name,
                                            indicator_name: value.indicator_name,
                                            indicator_short_name: value.indicator_short_name,
                                            creator: User.current.id,
                                            description: value.description,
                                            contents: value_contents_to_json(value.contents))

          raise "Failed to save report value: #{report_value.errors.as_json}" unless report_value.errors.empty?

          save_patients(report_value, value_contents_to_json(value).contents)

          report_value
        end
      end

      def clear_drill_down
        saved_reports = find_saved_report
        return if saved_reports.blank?

        ActiveRecord::Base.connection.execute <<~SQL
          DELETE FROM cohort_drill_down WHERE reporting_report_design_resource_id IN (#{saved_reports.join(',')})
        SQL
        ActiveRecord::Base.connection.execute <<~SQL
          DELETE FROM reporting_report_design_resource WHERE report_design_id IN (#{saved_reports.join(',')})
        SQL
        ActiveRecord::Base.connection.execute <<~SQL
          DELETE FROM reporting_report_design WHERE id IN (#{saved_reports.join(',')})
        SQL
      end

      def value_contents_to_json(value_contents)
        if value_contents.respond_to?(:each) && !value_contents.is_a?(String)
          if value_contents.respond_to?(:length)
            value_contents.length
          elsif value_contents.respond_to?(:size)
            value_contents.size
          else
            value_contents
          end
        else
          value_contents
        end
      end

      PATIENT_ID_KEYS = ['patient_id', :patient_id, 'person_id', :person_id].freeze

      def save_patients(r, values)
        return if values.blank? || !values.respond_to?(:each)

        get_patient_id = lambda do |patient, keys = PATIENT_ID_KEYS|
          break nil if keys.empty?

          patient[keys.first] || get_patient_id[patient, keys[1..keys.size]]
        end

        patient_ids = values.map do |patient|
          if patient.respond_to?(:key?) && PATIENT_ID_KEYS.any? { |key| patient.key?(key) }
            get_patient_id[patient]
          elsif patient.respond_to?(:each) && patient.respond_to?(:first)
            patient.first
          else
            patient
          end
        end

        sql_insert_statement = nil
        patient_ids.select do |patient_id|
          if sql_insert_statement.blank?
            sql_insert_statement = "(#{r.id}, #{patient_id})"
          else
            sql_insert_statement += ",(#{r.id}, #{patient_id})"
          end
        end

        return if sql_insert_statement.blank?

        ActiveRecord::Base.connection.execute <<~SQL
          INSERT INTO cohort_drill_down (reporting_report_design_resource_id, patient_id)
          VALUES #{sql_insert_statement};
        SQL
      end

      def calculate_age(birthdate)
        birthdate = begin
          birthdate.to_date
        rescue StandardError
          nil
        end
        return 'N/A' if birthdate.blank?

        birthdate = ActiveRecord::Base.connection.select_one <<~SQL
          SELECT TIMESTAMPDIFF(year, DATE('#{birthdate}'), DATE('#{@end_date}')) age;
        SQL

        birthdate['age']
      end
    end
  end
end
