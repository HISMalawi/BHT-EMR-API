# frozen_string_literal: true

require 'set'

module ARTService
  module Reports
    # Cohort report builder class.
    #
    # This class only provides one public method (start_build_report) besides
    # the constructor. This method must be called to build report and save
    # it to database.
    class Cohort
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
          clear_drill_down
          @cohort_builder.build(@cohort_struct, @start_date, @end_date, @occupation)
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
=begin
        data = ActiveRecord::Base.connection.select_all <<~SQL
          SELECT o.patient_id, min(start_date) start_date
          FROM orders o
          INNER JOIN drug_order od ON od.order_id = o.order_id AND o.voided = 0
          INNER JOIN drug d ON d.drug_id = od.drug_inventory_id
          INNER JOIN concept_set s ON s.concept_id = d.concept_id
          INNER JOIN patient_program pp ON pp.patient_id = o.patient_id
          WHERE s.concept_set = 1085
            AND od.quantity > 0
            AND pp.program_id = 1
            AND pp.voided = 0
            AND o.patient_id NOT IN (
              SELECT DISTINCT person_id
              FROM obs
              INNER JOIN encounter
                ON encounter.encounter_id = obs.encounter_id
                AND encounter.program_id = 1
                AND encounter.encounter_type IN (SELECT encounter_type_id FROM encounter_type WHERE name = 'Registration')
                AND encounter.encounter_datetime < DATE(#{ActiveRecord::Base.connection.quote(@end_date)}) + INTERVAL 1 DAY
                AND encounter.voided = 0
              WHERE obs.voided = 0
                AND obs.concept_id IN (SELECT concept_id FROM concept_name WHERE name = 'Type of Patient' AND voided = 0)
                AND obs.value_coded IN (SELECT concept_id FROM concept_name WHERE name = 'External consultation' AND voided = 0)
                AND obs.obs_datetime < DATE(#{ActiveRecord::Base.connection.quote(@end_date)})
            )
          GROUP BY o.patient_id;
        SQL
=end

        report_type = (pepfar ? 'pepfar' : 'moh')
        defaulter_date_sql = pepfar ? " current_pepfar_defaulter_date" : "current_defaulter_date"
        cohort_list = ARTService::Reports::CohortBuilder.new(outcomes_definition: report_type)
        cohort_list.create_tmp_patient_table
        cohort_list.drop_temp_register_start_date_table
        cohort_list.drop_temp_other_patient_types
        cohort_list.create_temp_other_patient_types(@end_date.to_date)
        cohort_list.create_temp_register_start_date_table(@end_date.to_date)
        cohort_list.load_data_into_temp_earliest_start_date(@end_date.to_date)

        outcomes = ARTService::Reports::Cohort::Outcomes.new(end_date: @end_date.to_date, definition: report_type)
        outcomes.update_cummulative_outcomes


        data = ActiveRecord::Base.connection.select_all <<~SQL
          SELECT
            e.patient_id, i.identifier arv_number, e.birthdate,
            e.gender, n.given_name, n.family_name,
            art_reason.name art_reason, a.value cell_number,
            s.state_province district, s.county_district ta,
            s.city_village village, TIMESTAMPDIFF(year, DATE(e.birthdate), DATE('#{@end_date}')) age,
            #{defaulter_date_sql}(e.patient_id, TIMESTAMP('#{@end_date.to_date.strftime('%Y-%m-%d 23:59:59')}')) AS defaulter_date
          FROM temp_earliest_start_date e
          INNER JOIN temp_patient_outcomes o ON e.patient_id = o.patient_id
          LEFT JOIN patient_identifier i ON i.patient_id = e.patient_id
          AND i.voided = 0 AND i.identifier_type = 4
          INNER JOIN person_name n ON n.person_id = e.patient_id AND n.voided = 0
          LEFT JOIN person_attribute a ON a.person_id = e.patient_id
          AND a.voided = 0 AND a.person_attribute_type_id = 12
          LEFT JOIN person_address s ON s.person_id = e.patient_id
          LEFT JOIN concept_name art_reason ON art_reason.concept_id = e.reason_for_starting_art
          WHERE o.cum_outcome = 'Defaulted' GROUP BY e.patient_id
          ORDER BY e.patient_id, n.date_created DESC;
        SQL

        patients = []

        (data || []).each do |person|
          defaulter_date = person['defaulter_date']&.to_date || 'N/A'

          unless defaulter_date == 'N/A'
            next if defaulter_date < @start_date.to_date
          end

          patients << {
            person_id: person["patient_id"],
            given_name: person['given_name'],
            family_name: person['family_name'],
            birthdate: person['birthdate'],
            gender: person['gender'],
            arv_number: person['arv_number'],
            outcome: 'Defaulted',
            defaulter_date: defaulter_date,
            art_reason: person['art_reason'],
            cell_number: person['cell_number'],
            district: person['district'],
            ta: person['ta'],
            village: person['village'],
            current_age: person['age']
          }
        end

        return patients
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

          { report: report, values: values }
        end
      end

      # Writes the report values to database
      def save_report_values(report)
        @cohort_struct.values.collect do |value|
          puts "Saving #{value.name} = #{value_contents_to_json(value.contents)}"
          report_value = ReportValue.create(report: report,
                                            name: value.name,
                                            indicator_name: value.indicator_name,
                                            indicator_short_name: value.indicator_short_name,
                                            creator: User.current.id,
                                            description: value.description,
                                            contents: value_contents_to_json(value.contents))

          unless report_value.errors.empty?
            raise "Failed to save report value: #{report_value.errors.as_json}"
          end

          save_patients(report_value, value_contents_to_json(value).contents)

          report_value
        end
      end

      def clear_drill_down
        ActiveRecord::Base.connection.execute <<~SQL
          TRUNCATE cohort_drill_down
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

        unless sql_insert_statement.blank?
          ActiveRecord::Base.connection.execute <<EOF
          INSERT INTO cohort_drill_down (reporting_report_design_resource_id, patient_id)
          VALUES #{sql_insert_statement};
EOF

        end

      end

      def  calculate_age(birthdate)
        birthdate = birthdate.to_date rescue nil
        return 'N/A' if birthdate.blank?

        birthdate = ActiveRecord::Base.connection.select_one <<~SQL
          SELECT TIMESTAMPDIFF(year, DATE('#{birthdate}'), DATE('#{@end_date}')) age;
        SQL

        return birthdate['age']
      end

    end
  end


end
