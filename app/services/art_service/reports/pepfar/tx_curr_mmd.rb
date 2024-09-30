# rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity, Style/Documentation
# frozen_string_literal: true

require 'parallel'

module ArtService
  module Reports
    module Pepfar
      class TxCurrMmd
        include ModelUtils
        include Pepfar::Utils
        include CommonSqlQueryUtils

        attr_reader :report

        def initialize(start_date:, end_date:, **kwargs)
          @start_date = start_date.to_date.strftime('%Y-%m-%d 00:00:00')
          @end_date = end_date.to_date.strftime('%Y-%m-%d 23:59:59')
          @org = kwargs[:definition]
          @rebuild = kwargs[:rebuild]&.casecmp?('true')
          @occupation = kwargs[:occupation]
          @report = init_report
        end

        def init_report
          filtered_pepfar_age_groups.each_with_object({}) do |age_group, report|
            report[age_group] = %w[Male Female].each_with_object({}) do |gender, age_group_report|
              age_group_report[gender] = {
                less_than_three_months: [],
                three_to_five_months: [],
                greater_than_six_months: []
              }
            end
          end
        end

        private

        def find_report
          report_type = (@org.match(/pepfar/i) ? 'pepfar' : 'moh')
          if @rebuild
            ArtService::Reports::CohortBuilder\
              .new(outcomes_definition: report_type)\
              .init_temporary_tables(@start_date, @end_date, @occupation)
          end

          patients = ActiveRecord::Base.connection.select_all <<~SQL
            SELECT tesd.patient_id,
                CASE tesd.gender
                  WHEN 'M' THEN 'Male'
                  WHEN 'F' THEN 'Female'
                  ELSE 'Unknown'
                END gender,
                disaggregated_age_group(tesd.birthdate, '#{@end_date}') age_group,
                TIMESTAMPDIFF(DAY, tcm.start_date, tcm.auto_expiry_date) prescribed_days
            FROM temp_earliest_start_date tesd
            INNER JOIN temp_patient_outcomes tpo ON tpo.patient_id = tesd.patient_id AND tpo.#{report_type&.downcase == 'pepfar' ? 'pepfar_' : 'moh_' }cum_outcome = 'On antiretrovirals'
            INNER JOIN temp_current_medication tcm ON tcm.patient_id = tesd.patient_id
            WHERE tesd.date_enrolled <= '#{@end_date}' AND tesd.gender IN ('M', 'F')
            GROUP BY tesd.patient_id
          SQL

          return {} if patients.blank?

          threads = ENV.fetch('RAILS_MAX_THREADS', 5).to_i
          mutex = Mutex.new

          Parallel.each(patients, in_threads: threads - 1) do |patient|
            prescribe_days = patient['prescribed_days'].to_i
            age_group = patient['age_group']
            gender = patient['gender']

            indicator = if prescribe_days < 90
                          'less_than_three_months'
                        elsif prescribe_days >= 90 && prescribe_days <= 150
                          'three_to_five_months'
                        elsif prescribe_days > 150
                          'greater_than_six_months'
                        end

            mutex.synchronize do
              report[age_group][gender][indicator.to_sym] << patient['patient_id']
            end
          end

          report
        end

        def filtered_pepfar_age_groups
          age_groups = pepfar_age_groups.dup # Create a local copy of the frozen array
          age_groups.reject { |age_group| age_group == 'Unknown' }
        end
      end
    end
  end
end
# rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity, Style/Documentation
