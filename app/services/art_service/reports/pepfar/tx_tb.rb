# frozen_string_literal: true

module ARTService
  module Reports
    module Pepfar
      # TxTB report
      # rubocop:disable Metrics/ClassLength
      class TxTB
        attr_accessor :start_date, :end_date, :report, :rebuild_outcome

        include Utils

        def initialize(start_date:, end_date:, **kwargs)
          @start_date = start_date.to_date.strftime('%Y-%m-%d 00:00:00')
          @end_date = end_date.to_date.strftime('%Y-%m-%d 23:59:59')
          @rebuild_outcome = ActiveModel::Type::Boolean.new.cast(kwargs[:rebuild_outcome]) || false
        end

        def find_report
          drop_temporary_tables
          init_report
          build_cohort_tables
          process_tb_screening
          process_tb_confirmed_and_on_treatment
          process_patients_alive_and_on_art
          process_tb_screened
          report
        end

        private

        def init_report
          @report = initialize_report_structure
        end

        def initialize_report_structure
          pepfar_age_groups.each_with_object({}) do |age_group, report|
            genders = %i[M F]
            genders.each do |gender|
              report[age_group] ||= {}
              report[age_group][gender] = initialize_gender_metrics
            end
          end
        end

        def initialize_gender_metrics
          {
            tx_curr: [],
            sceen_pos_new: [],
            sceen_neg_new: [],
            started_tb_new: [],
            sceen_pos_prev: [],
            sceen_neg_prev: [],
            started_tb_prev: []
          }
        end

        def drop_temporary_tables
          execute_action('DROP TABLE IF EXISTS temp_tb_screened;')
          execute_action('DROP TABLE IF EXISTS temp_tb_confirmed_and_on_treatment;')
        end

        def build_cohort_tables
          return unless rebuild_outcome

          cohort_builder = ARTService::Reports::CohortBuilder.new(outcomes_definition: 'pepfar')
          cohort_builder.init_temporary_tables(start_date, end_date)
        end

        def process_tb_screening
          execute_query(create_temp_tb_screened_query)
        end

        def create_temp_tb_screened_query
          <<~SQL
            CREATE TABLE temp_tb_screened AS
            SELECT o.person_id as patient_id,
            LEFT(tesd.gender, 1) AS gender, MAX(o.obs_datetime) AS screened_date,
            tesd.earliest_start_date as enrollment_date,
            disaggregated_age_group(tesd.birthdate, DATE('#{end_date.to_date}')) AS age_group,
            (SELECT name FROM concept_name WHERE concept_id = o.value_coded AND o.voided = 0 LIMIT 1) AS tb_status
            FROM obs o
            INNER JOIN temp_earliest_start_date tesd ON tesd.patient_id = o.person_id
            WHERE o.concept_id = #{ConceptName.find_by_name('TB status').concept_id}
            AND o.voided = 0 AND o.value_coded IN (#{ConceptName.find_by_name('TB Suspected').concept_id}, #{ConceptName.find_by_name('TB NOT suspected').concept_id})
            AND o.obs_datetime BETWEEN '#{start_date}' AND '#{end_date}'
            GROUP BY o.person_id
          SQL
        end

        def process_tb_confirmed_and_on_treatment
          execute_query(create_temp_tb_confirmed_query)
        end

        def create_temp_tb_confirmed_query
          <<~SQL
            CREATE TABLE temp_tb_confirmed_and_on_treatment AS
            SELECT o.person_id as patient_id, MIN(o.obs_datetime) AS tb_confirmed_date
            FROM obs o
            WHERE o.concept_id = #{ConceptName.find_by_name('TB status').concept_id}
            AND o.value_coded = #{ConceptName.find_by_name('Confirmed TB on treatment').concept_id}
            AND o.voided = 0
            AND o.obs_datetime BETWEEN '#{start_date}' AND '#{end_date}'
            AND o.person_id IN (SELECT patient_id FROM temp_tb_screened)
            GROUP BY o.person_id
          SQL
        end

        def process_patients_alive_and_on_art
          find_patients_alive_and_on_art.each do |patient|
            next unless pepfar_age_groups.include?(patient['age_group'])

            @report[patient['age_group']][patient['gender'].to_sym][:tx_curr] << patient['patient_id']
          end
        end

        def find_patients_alive_and_on_art
          execute_query(create_patients_alive_and_on_art_query)
        end

        def create_patients_alive_and_on_art_query
          <<~SQL
            SELECT tpo.patient_id, LEFT(tesd.gender, 1) AS gender, disaggregated_age_group(tesd.birthdate, DATE('#{end_date.to_date}')) age_group
            FROM temp_patient_outcomes tpo
            INNER JOIN temp_earliest_start_date tesd ON tesd.patient_id = tpo.patient_id
            WHERE tpo.cum_outcome = 'On antiretrovirals'
          SQL
        end

        # rubocop:disable Metrics/AbcSize
        # rubocop:disable Metrics/MethodLength
        # rubocop:disable Metrics/CyclomaticComplexity
        # rubocop:disable Metrics/PerceivedComplexity
        def process_tb_screened
          tb_screened_data = find_tb_screened_data
          tb_screened_data.each do |patient|
            age_group = patient['age_group']
            next unless pepfar_age_groups.include?(age_group)

            gender = patient['gender'].to_sym
            metrics = @report[age_group][gender]
            enrollment_date = patient['enrollment_date']
            tb_status = patient['tb_status'].downcase
            tb_confirmed_date = patient['tb_confirmed_date']

            if new_on_art(enrollment_date)
              metrics[:sceen_pos_new] << patient['patient_id'] if ['tb suspected', 'sup'].include?(tb_status)
              metrics[:sceen_neg_new] << patient['patient_id'] if ['tb not suspected', 'nosup'].include?(tb_status)
              metrics[:started_tb_new] << patient['patient_id'] if tb_confirmed_date.present?
            else
              metrics[:sceen_pos_prev] << patient['patient_id'] if ['tb suspected', 'sup'].include?(tb_status)
              metrics[:sceen_neg_prev] << patient['patient_id'] if ['tb not suspected', 'nosup'].include?(tb_status)
              metrics[:started_tb_prev] << patient['patient_id'] if tb_confirmed_date.present?
            end
          end
        end
        # rubocop:enable Metrics/AbcSize
        # rubocop:enable Metrics/MethodLength
        # rubocop:enable Metrics/CyclomaticComplexity
        # rubocop:enable Metrics/PerceivedComplexity

        def execute_query(query)
          ActiveRecord::Base.connection.select_all(query)
        end

        def execute_action(query)
          ActiveRecord::Base.connection.execute(query)
        end

        def find_tb_screened_data
          execute_query(find_tb_screened_data_query)
        end

        def find_tb_screened_data_query
          <<~SQL
            SELECT tbs.patient_id, tbs.enrollment_date, LEFT(tbs.gender, 1) AS gender, tbs.age_group, tbs.tb_status, tbs.screened_date, tbcot.tb_confirmed_date
            FROM temp_tb_screened tbs
            LEFT JOIN temp_tb_confirmed_and_on_treatment tbcot ON tbcot.patient_id = tbs.patient_id
          SQL
        end

        def new_on_art(earliest_start_date)
          six_months_later = earliest_start_date.to_date + 6.months
          six_months_later > end_date.to_date
        end
      end
      # rubocop:enable Metrics/ClassLength
    end
  end
end
