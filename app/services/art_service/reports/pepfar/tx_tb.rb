# frozen_string_literal: true

module ARTService
  module Reports
    module Pepfar
      # TxTb report
      # rubocop:disable Metrics/ClassLength
      class TxTB
        attr_accessor :start_date, :end_date, :report, :rebuild_outcome

        include Utils

        def initialize(start_date:, end_date:, **kwargs)
          @start_date = start_date.to_date.strftime('%Y-%m-%d 00:00:00')
          @end_date = end_date.to_date.strftime('%Y-%m-%d 23:59:59')
          @rebuild_outcome = ActiveModel::Type::Boolean.new.cast(kwargs[:rebuild_outcome]) || false
          @occupation = kwargs[:occupation]
        end

        def find_report
          drop_temporary_tables
          create_temp_earliest_start_date unless temp_eartliest_start_date_exists?
          init_report
          build_cohort_tables
          process_tb_screening
          process_tb_confirmed_and_on_treatment
          process_patients_alive_and_on_art
          process_tb_screened
          process_tb_confirmed
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
            symptom_screen_alone: [],
            cxr_screen: [],
            mwrd_screen: [],
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
          return unless rebuild_outcome || @occupation.present?

          cohort_builder = ARTService::Reports::CohortBuilder.new(outcomes_definition: 'pepfar')
          cohort_builder.init_temporary_tables(start_date, end_date, @occupation)
        end

        def process_tb_screening
          execute_action(create_temp_tb_screened_query)
        end

        def create_temp_tb_screened_query
          <<~SQL
            CREATE TABLE temp_tb_screened AS
            SELECT
              o.person_id as patient_id,
              LEFT(current_obs.gender, 1) AS gender, MAX(o.obs_datetime) AS screened_date,
              current_obs.earliest_start_date as enrollment_date,
              disaggregated_age_group(current_obs.birthdate, DATE('#{end_date.to_date}')) AS age_group,
              cn.name AS tb_status,
              GROUP_CONCAT(DISTINCT vcn.name) AS screening_methods
            FROM obs o
            INNER JOIN (
              SELECT o.person_id, MAX(o.obs_datetime) AS obs_datetime, tesd.earliest_start_date, tesd.gender, tesd.birthdate
              FROM obs o
              INNER JOIN temp_earliest_start_date tesd ON tesd.patient_id = o.person_id
              WHERE o.concept_id = #{ConceptName.find_by_name('TB status').concept_id}
              AND o.voided = 0 AND o.obs_datetime BETWEEN '#{start_date}' AND '#{end_date}'
              GROUP BY o.person_id
            ) current_obs ON current_obs.person_id = o.person_id AND current_obs.obs_datetime = o.obs_datetime
            INNER JOIN concept_name cn ON cn.concept_id = o.value_coded AND cn.voided = 0
            LEFT JOIN obs screen_method ON screen_method.concept_id = #{ConceptName.find_by_name('TB screening method used').concept_id} AND screen_method.voided = 0 AND screen_method.person_id = o.person_id AND DATE(screen_method.obs_datetime) = DATE(current_obs.obs_datetime)
            LEFT JOIN concept_name vcn ON vcn.concept_id = o.value_coded AND vcn.voided = 0 AND vcn.name IN ('CXR', 'MWRD')
            WHERE o.concept_id = #{ConceptName.find_by_name('TB status').concept_id}
            AND o.voided = 0
            AND o.value_coded IN (SELECT concept_id FROM concept_name WHERE name IN ('TB Suspected', 'TB NOT suspected', 'Confirmed TB NOT on treatment', 'Confirmed TB on treatment') AND voided = 0)
            AND o.obs_datetime BETWEEN '#{start_date}' AND '#{end_date}'
            GROUP BY o.person_id
          SQL
        end

        def temp_eartliest_start_date_exists?
          ActiveRecord::Base.connection.table_exists?('temp_earliest_start_date')
        end

        def create_temp_earliest_start_date
          cohort_builder = ArtService::Reports::CohortBuilder.new(outcomes_definition: 'pepfar')
          cohort_builder.init_temporary_tables(start_date, end_date, @occupation)
        end

        def process_tb_confirmed_and_on_treatment
          execute_action(create_temp_tb_confirmed_query)
        end

        def create_temp_tb_confirmed_query
          <<~SQL
            CREATE TABLE temp_tb_confirmed_and_on_treatment AS
            SELECT
              o.person_id as patient_id,
              LEFT(p.gender, 1) AS gender,
              disaggregated_age_group(p.birthdate, DATE('#{end_date.to_date}')) AS age_group,
              COALESCE(MIN(tcd.value_datetime),MIN(o.obs_datetime)) AS tb_confirmed_date,
              CASE
                WHEN COUNT(tcd.value_datetime) > 0 THEN TRUE
                ELSE FALSE
              END AS has_tb_confirmed_date,
              tesd.earliest_start_date as enrollment_date,
              prev.tb_confirmed_date prev_reading
            FROM obs o
            INNER JOIN temp_earliest_start_date tesd ON tesd.patient_id = o.person_id
            INNER JOIN person p ON p.person_id = o.person_id AND p.voided = 0
            LEFT JOIN obs tcd ON tcd.concept_id = #{ConceptName.find_by_name('TB treatment start date').concept_id} AND tcd.voided = 0 AND tcd.person_id = o.person_id
            LEFT JOIN (
              SELECT
                o.person_id,
                COALESCE(MAX(tcd.value_datetime),MAX(o.obs_datetime)) AS tb_confirmed_date
              FROM obs o
              LEFT JOIN obs tcd ON tcd.concept_id = #{ConceptName.find_by_name('TB treatment start date').concept_id} AND tcd.voided = 0 AND tcd.person_id = o.person_id
              WHERE o.concept_id = #{ConceptName.find_by_name('TB status').concept_id}
              AND o.value_coded = #{ConceptName.find_by_name('Confirmed TB on treatment').concept_id}
              AND o.voided = 0
              AND o.obs_datetime <= '#{start_date}'
              GROUP BY o.person_id
            ) prev ON prev.person_id = o.person_id
            WHERE o.concept_id = #{ConceptName.find_by_name('TB status').concept_id}
            AND o.value_coded = #{ConceptName.find_by_name('Confirmed TB on treatment').concept_id}
            AND o.voided = 0
            AND o.obs_datetime BETWEEN '#{start_date}' AND '#{end_date}'
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
        def process_tb_screened
          tb_screened_data = find_tb_screened_data
          tb_screened_data.each do |patient|
            age_group = patient['age_group']
            next unless pepfar_age_groups.include?(age_group)

            gender = patient['gender'].to_sym
            metrics = @report[age_group][gender]
            enrollment_date = patient['enrollment_date']
            tb_status = patient['tb_status'].downcase
            screening_methods = patient['screening_methods']&.split(',')&.map(&:downcase)
            patient_id = patient['patient_id']
            process_method(metrics, screening_methods, patient_id)
            process_screening_results(metrics, enrollment_date, tb_status, patient_id)
          end
        end

        def process_tb_confirmed
          find_tb_confirmed_data.each do |patient|
            age_group = patient['age_group']
            next unless pepfar_age_groups.include?(age_group)

            gender = patient['gender'].to_sym
            metrics = @report[age_group][gender]
            enrollment_date = patient['enrollment_date']

            if new_on_art(enrollment_date)
              metrics[:started_tb_new] << patient['patient_id']
            else
              metrics[:started_tb_prev] << patient['patient_id']
            end
          end
        end

        def process_screening_results(metrics, enrollment_date, tb_status, patient_id)
          if new_on_art(enrollment_date)
            metrics[:sceen_pos_new] << patient_id if ['tb suspected', 'sup', 'confirmed tb not on treatment', 'norx', 'confirmed tb on treatment', 'rx'].include?(tb_status)
            metrics[:sceen_neg_new] << patient_id if ['tb not suspected', 'nosup'].include?(tb_status)
          else
            metrics[:sceen_pos_prev] << patient_id if ['tb suspected', 'sup', 'confirmed tb not on treatment', 'norx'].include?(tb_status)
            metrics[:sceen_neg_prev] << patient_id if ['tb not suspected', 'nosup'].include?(tb_status)
          end
        end

        def process_method(metrics, methods, patient_id)
          metrics[:symptom_screen_alone] << patient_id if methods.blank?
          metrics[:cxr_screen] << patient_id if methods&.include?('cxr') && !methods&.include?('mwrd')
          metrics[:mwrd_screen] << patient_id if methods&.include?('mwrd')
        end

        # rubocop:enable Metrics/AbcSize
        # rubocop:enable Metrics/MethodLength

        def execute_query(query)
          ActiveRecord::Base.connection.select_all(query)
        end

        def execute_action(query)
          ActiveRecord::Base.connection.execute(query)
        end

        def find_tb_screened_data
          execute_query(find_tb_screened_data_query)
        end

        def find_tb_confirmed_data
          execute_query(find_tb_confirmed_data_query)
        end

        def find_tb_method_data
          execute_query(find_tb_method_data_query)
        end

        def find_tb_screened_data_query
          <<~SQL
            SELECT tbs.patient_id, tbs.enrollment_date, LEFT(tbs.gender, 1) AS gender, tbs.age_group, tbs.tb_status, tbs.screened_date, tbs.screening_methods
            FROM temp_tb_screened tbs
          SQL
        end

        def find_tb_confirmed_data_query
          <<~SQL
            SELECT t.patient_id, t.gender, t.age_group, t.enrollment_date, t.tb_confirmed_date
            FROM temp_tb_confirmed_and_on_treatment t
            WHERE t.tb_confirmed_date > '#{start_date}'
            AND (t.has_tb_confirmed_date = TRUE OR t.prev_reading IS NULL OR TIMESTAMPDIFF(MONTH,t.prev_reading, t.tb_confirmed_date) > 6)
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
