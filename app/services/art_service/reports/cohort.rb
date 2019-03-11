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
      include ModelUtils

      def initialize(name:, type:, start_date:, end_date:)
        @name = name
        @start_date = start_date
        @end_date = end_date
        @type = type
        @cohort_builder = CohortBuilder.new
        @cohort_struct = CohortStruct.new
      end

      def build_report
        @cohort_builder.build(@cohort_struct, @start_date, @end_date)
        save_report
      end

      def find_report
        Report.where(type: @type, name: @name,
                     start_date: @start_date, end_date: @end_date)\
              .order(date_created: :desc)\
              .first
      end

      def raw_data(l1, l2)
        data = ActiveRecord::Base.connection.select_all <<EOF
        SELECT e.*, t2.cum_outcome,  
        t3.identifier arv_number, t.birthdate,
        t.gender, t4.given_name, t4.family_name
        FROM temp_earliest_start_date e 
        INNER JOIN person t ON t.person_id = e.patient_id
        INNER JOIN temp_patient_outcomes t2 ON t2.patient_id = e.patient_id
        LEFT JOIN patient_identifier t3 ON t3.patient_id = e.patient_id
        AND t3.voided = 0 AND t3.identifier_type = 4 
        INNER JOIN person_name t4 ON t4.person_id = e.patient_id
        AND t4.voided = 0 GROUP BY t2.patient_id LIMIT #{l1}, #{l2};
EOF

        list = [];
        (data || []).each do |record|
          list << {
            patient_id: record['patient_id'],
            given_name: record['given_name'],
            family_name: record['family_name'],
            birthdate: record['birthdate'],
            gender: record['gender'],
            date_enrolled: record['date_enrolled'],
            earliest_start_date: record['earliest_start_date'],
            arv_number: record['arv_number'],
            outcome:  record['cum_outcome']
          }
        end

        return list
      end

      private

      LOGGER = Rails.logger

      # Writes the report to database
      def save_report
        report = Report.create(name: @name, start_date: @start_date,
                               end_date: @end_date, type: @type,
                               renderer_type: 'PDF')

        values = save_report_values(report)

        { report: report, values: values }
      end

      # Writes the report values to database
      def save_report_values(report)
        @cohort_struct.values.collect do |value|
          puts "Saving #{value.name} = #{value_contents_to_json(value.contents)}"
          report_value = ReportValue.create(report: report,
                                            name: value.name,
                                            indicator_name: value.indicator_name,
                                            indicator_short_name: value.indicator_short_name,
                                            description: value.description,
                                            contents: value_contents_to_json(value.contents))

          report_value_saved = report_value.errors.empty?
          unless report_value_saved
            raise "Failed to save report value: #{report_value.errors.as_json}"
          end

          report_value
        end
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
    end
  end
end
