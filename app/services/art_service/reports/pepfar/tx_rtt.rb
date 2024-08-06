# frozen_string_literal: true

module ArtService
  module Reports
    module Pepfar
      class TxRtt
        attr_reader :start_date, :end_date, :rebuild, :occupation

        include CommonSqlQueryUtils
        include Utils

        def initialize(start_date:, end_date:, **kwargs)
          @start_date = ActiveRecord::Base.connection.quote(start_date.to_date.beginning_of_day.strftime('%Y-%m-%d %H:%M:%S'))
          @end_date = ActiveRecord::Base.connection.quote(end_date.to_date.end_of_day.strftime('%Y-%m-%d %H:%M:%S'))
          @occupation = kwargs[:occupation]
          @rebuild = kwargs[:rebuild]&.casecmp?(true)
        end

        def find_report
          if rebuild
            ArtService::Reports::CohortBuilder.new(outcomes_definition: 'pepfar').init_temporary_tables(start_date,
                                                                                                        end_date, occupation)
          end
          process_report
        end

        def data
          if rebuild
            ArtService::Reports::CohortBuilder.new(outcomes_definition: 'pepfar').init_temporary_tables(start_date,
                                                                                                        end_date, occupation)
          end
          process_report
        rescue StandardError => e
          Rails.logger.error "Error running TX_RTT Report: #{e}"
          Rails.logger.error e.backtrace.join("\n")
          raise e
        end

        private

        GENDER = %w[M F].freeze

        def init_report
          pepfar_age_groups.each_with_object({}) do |age_group, age_group_report|
            age_group_report[age_group] = GENDER.each_with_object({}) do |gender, gender_report|
              gender_report[gender] = indicators
            end
          end
        end

        def process_report
          report = init_report
          process_data report
          flatten_the_report report
        end

        def process_data(report)
          fetch_data.each do |row|
            age_group = row['age_group']
            gender = row['gender']
            months = row['months']
            patient_id = row['patient_id']
            cd4_cat = row['cd4_count_group']

            next unless GENDER.include?(gender)
            next unless pepfar_age_groups.include?(age_group)

            cat = report[age_group][gender]
            process_months(cat, months, patient_id)
            process_cd4(cat, months, patient_id, cd4_cat)
          end
        end

        def process_months(report, months, patient_id)
          return report[:returned_less_than_3_months] << patient_id if months.blank?
          return report[:returned_less_than_3_months] << patient_id if months < 3
          if months >= 3 && months < 6
            return report[:returned_greater_than_3_months_and_less_than_6_months] << patient_id
          end

          report[:returned_greater_than_or_equal_to_6_months] << patient_id if months >= 6
        end

        def process_cd4(report, months, patient_id, cd4_cat)
          if cd4_cat == 'unknown_cd4_count' && (months.blank? || months <= 2)
            report[:not_eligible_for_cd4] << patient_id
            return
          end

          report[cd4_cat.to_sym] << patient_id
        end

        def indicators
          {
            'cd4_less_than_200': [],
            'cd4_greater_than_or_equal_to_200': [],
            'unknown_cd4_count': [],
            'not_eligible_for_cd4': [],
            'returned_less_than_3_months': [],
            'returned_greater_than_3_months_and_less_than_6_months': [],
            'returned_greater_than_or_equal_to_6_months': []
          }
        end

        def process_age_group_report(age_group, gender, age_group_report)
          {
            age_group:,
            gender:,
            cd4_less_than_200: age_group_report[:cd4_less_than_200],
            cd4_greater_than_or_equal_to_200: age_group_report[:cd4_greater_than_or_equal_to_200],
            unknown_cd4_count: age_group_report[:unknown_cd4_count],
            not_eligible_for_cd4: age_group_report[:not_eligible_for_cd4],
            returned_less_than_3_months: age_group_report[:returned_less_than_3_months],
            returned_greater_than_3_months_and_less_than_6_months: age_group_report[:returned_greater_than_3_months_and_less_than_6_months],
            returned_greater_than_or_equal_to_6_months: age_group_report[:returned_greater_than_or_equal_to_6_months]
          }
        end

        def flatten_the_report(report)
          result = []
          report.each do |age_group, age_group_report|
            result << process_age_group_report(age_group, 'M', age_group_report['M'])
            result << process_age_group_report(age_group, 'F', age_group_report['F'])
          end
          sorted_results = result.sort_by do |item|
            gender_score = item[:gender] == 'Female' ? 0 : 1
            age_group_score = pepfar_age_groups.index(item[:age_group])
            [gender_score, age_group_score]
          end
          # sort by gender, start all females and push all males to the end
          sorted_results.sort_by { |h| [h[:gender] == 'F' ? 0 : 1] }
        end

        def fetch_data
          ActiveRecord::Base.connection.select_all <<~SQL
            SELECT
              e.patient_id,
              disaggregated_age_group(e.birthdate, #{end_date}) AS age_group,
              e.gender,
              s.cum_outcome initial_outcome,
              o.cum_outcome final_outcome,
              TIMESTAMPDIFF(MONTH, COALESCE(s.outcome_date, c.outcome_date), ord.min_order_date) months,
              CASE
                WHEN cd4_result.value_numeric < 200 THEN 'cd4_less_than_200'
                WHEN cd4_result.value_numeric = 200 AND cd4_result.value_modifier = '=' THEN 'cd4_greater_than_or_equal_to_200'
                WHEN cd4_result.value_numeric = 200 AND cd4_result.value_modifier = '<' THEN 'cd4_less_than_200'
                WHEN cd4_result.value_numeric = 200 AND cd4_result.value_modifier = '>' THEN 'cd4_greater_than_or_equal_to_200'
                WHEN cd4_result.value_numeric > 200 THEN 'cd4_greater_than_or_equal_to_200'
                ELSE 'unknown_cd4_count'
              END cd4_count_group
            FROM temp_earliest_start_date e
            INNER JOIN temp_patient_outcomes o ON o.patient_id = e.patient_id AND o.cum_outcome = 'On antiretrovirals'
            INNER JOIN temp_patient_outcomes_start s ON s.patient_id = e.patient_id AND s.cum_outcome IN ('Defaulted', 'Treatment stopped')
            LEFT JOIN temp_current_state_start c ON c.patient_id = e.patient_id
            INNER JOIN temp_max_drug_orders ord ON ord.patient_id = e.patient_id
            LEFT JOIN obs cd4_result ON cd4_result.person_id = e.patient_id AND cd4_result.concept_id = #{concept_name('CD4 count').concept_id} AND cd4_result.voided = 0
            GROUP BY e.patient_id
          SQL
        end
      end
    end
  end
end
