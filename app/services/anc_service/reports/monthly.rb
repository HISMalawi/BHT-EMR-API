# frozen_string_literal: true

require 'set'

module ANCService
  module Reports
    # Cohort report builder class.
    #
    # This class only provides one public method (start_build_report) besides
    # the constructor. This method must be called to build report and save
    # it to database.
    class Monthly
      include ModelUtils

      def initialize(name:, type:, start_date:, end_date:)
        @name = name
        @start_date = start_date.to_date.beginning_of_month
        @end_date = end_date.to_date.end_of_month
        @type = type
        @cohort_builder = MonthlyBuilder.new
        @cohort_struct = MonthlyStruct.new
        t = ARTService::Reports::CohortBuilder.new #.create_tmp_patient_table

        t.create_tmp_patient_table
        t.load_data_into_temp_earliest_start_date(@end_date.to_date)
      end

      def build_report
        @cohort_builder.build(@cohort_struct, @start_date, @end_date)
      end

      def find_report
        build_report
        #Report.where(type: @type, name: @name,
        #             start_date: @start_date, end_date: @end_date)\
        #      .order(date_created: :desc)\
        #      .first
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