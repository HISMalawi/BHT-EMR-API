# rubocop:disable Metrics/BlockLength
module ARTService
  module Reports
    module Pepfar
      class TxTB
        attr_accessor :start_date, :end_date, :report

        include Utils

        def initialize(start_date:, end_date:, **_kwargs)
          @start_date = start_date.to_date.strftime('%Y-%m-%d 00:00:00')
          @end_date = end_date.to_date.strftime('%Y-%m-%d 23:59:59')
        end

        # First of we need to get the patients who are alive and on treatment
        # 1. We will rebuild the outcomes for the patients
        # 2. We will get all clients who are 'On Antiretrovirals'
        # 3. We will then get clients who have been screened for TB from the start_date to the end_date the become our denominator
        # 4. Our numerator will be those clients who were TB confirmed and started on treatment (even though prior to this we where capturing the details)
        def find_report
          drop_temporary_tables
          init_report
          ARTService::Reports::CohortBuilder.new(outcomes_definition: 'pepfar').init_temporary_tables(start_date, end_date)
          clients_screened_for_tb
          clients_confirmed_tb_and_on_treatment
          tx_curr = find_patients_alive_and_on_art
          tx_curr.each { |patient| report[patient['age_group']][patient['gender'].to_sym][:tx_curr] << patient['patient_id'] }
          tb_screened.each do |patient|
            next unless pepfar_age_groups.include?(patient['age_group'])
            
            report[age_group][patient['gender'].to_sym][:sceen_pos_new] << patient['patient_id'] if new_on_art(patient['enrollment_date']) && ['TB Suspected', 'sup'].include?(patient['tb_status'])
            report[age_group][patient['gender'].to_sym][:sceen_neg_new] << patient['patient_id'] if new_on_art(patient['enrollment_date']) && ['TB NOT suspected', 'Nosup'].include?(patient['tb_status'])
            report[age_group][patient['gender'].to_sym][:started_tb_new] << patient['patient_id'] if new_on_art(patient['enrollment_date']) && patient['tb_confirmed_date'].present?
            report[age_group][patient['gender'].to_sym][:sceen_pos_prev] << patient['patient_id'] if !new_on_art(patient['enrollment_date']) && ['TB Suspected', 'sup'].include?(patient['tb_status'])
            report[age_group][patient['gender'].to_sym][:sceen_neg_prev] << patient['patient_id'] if !new_on_art(patient['enrollment_date']) && ['TB NOT suspected', 'Nosup'].include?(patient['tb_status'])
            report[age_group][patient['gender'].to_sym][:started_tb_prev] << patient['patient_id'] if !new_on_art(patient['enrollment_date']) && patient['tb_confirmed_date'].present?
          end
          report
        end

        def init_report
          @report = pepfar_age_groups.each_with_object({}) do |age_group, report|
            %i[M F].collect do |gender|
              report[age_group] ||= {}
              report[age_group][gender] = {
                tx_curr: [],
                sceen_pos_new: [],
                sceen_neg_new: [],
                started_tb_new: [],
                sceen_pos_prev: [],
                sceen_neg_prev: [],
                started_tb_prev: []
              }
            end
          end
        end

        def drop_temporary_tables
          ActiveRecord::Base.connection.execute 'DROP TABLE IF EXISTS temp_tb_screened;'
          ActiveRecord::Base.connection.execute 'DROP TABLE IF EXISTS temp_tb_confirmed_and_on_treatment;'
        end

        def arv_concepts
          @arv_concepts ||= ConceptSet.where(concept_set: ConceptName.where(name: 'Antiretroviral drugs')
                                                                    .select(:concept_id))
                                      .collect(&:concept_id).join(',')
        end

        def find_patients_alive_and_on_art
          ActiveRecord::Base.connection.select_all <<~SQL
            SELECT tpo.patient_id, LEFT(tesd.gender, 1) AS gender, disaggregated_age_group(tesd.birthdate, DATE('#{end_date.to_date}')) age_group
            FROM temp_patient_outcomes tpo
            INNER JOIN temp_earliest_start_date tesd ON tesd.patient_id = tpo.patient_id
            WHERE tpo.cum_outcome = 'On antiretrovirals'
          SQL
        end

        def new_on_art(earliest_start_date)
          earliest_start_date = earliest_start_date.to_date + 6.months
          earliest_start_date >= end_date.to_date
        end

        def clients_screened_for_tb
          ActiveRecord::Base.connection.select_all <<~SQL
            CREATE TABLE temp_tb_screened AS
            SELECT DISTINCT(o.person_id) as patient_id,
            LEFT(tesd.gender, 1) AS gender, MAX(o.obs_datetime) AS screened_date,
            tesd.earliest_start_date as enrollment_date,
            disaggregated_age_group(tesd.birthdate, DATE(#{ActiveRecord::Base.connection.quote(end_date.to_date)})) AS age_group,
            (SELECT name FROM concept_name WHERE concept_id = o.value_coded AND o.voided = 0 LIMIT 1) AS tb_status
            FROM obs o
            INNER JOIN temp_earliest_start_date tesd ON tesd.patient_id = o.person_id
            WHERE o.concept_id = #{ConceptName.find_by_name('TB status').concept_id}
            AND o.voided = 0 AND o.value_coded IN (#{ConceptName.find_by_name('TB Suspected').concept_id}, #{ConceptName.find_by_name('TB NOT suspected').concept_id})
            AND o.obs_datetime BETWEEN '#{start_date}' AND '#{end_date}'
            GROUP BY o.person_id
          SQL
        end

        def clients_confirmed_tb_and_on_treatment
          ActiveRecord::Base.connection.select_all <<~SQL
            CREATE TABLE temp_tb_confirmed_and_on_treatment AS
            SELECT o.person_id as patient_id, MIN(o.obs_datetime) AS tb_confirmed_date -- we might need to debate on this
            FROM obs o
            WHERE o.concept_id = #{ConceptName.find_by_name('TB status').concept_id}
            AND o.value_coded = #{ConceptName.find_by_name('Confirmed TB on treatment').concept_id}
            AND o.voided = 0
            AND o.obs_datetime BETWEEN '#{start_date}' AND '#{end_date}'
            AND o.person_id IN(SELECT patient_id FROM temp_tb_screened)
            GROUP BY o.person_id
          SQL
        end

        def tb_screened
          ActiveRecord::Base.connection.select_all <<~SQL
            SELECT tbs.patient_id, tbs.enrollment_date, LEFT(tbs.gender, 1) AS gender, tbs.age_group, tbs.tb_status, tbs.screened_date, tbcot.tb_confirmed_date
            FROM temp_tb_screened tbs
            LEFT JOIN temp_tb_confirmed_and_on_treatment tbcot ON tbcot.patient_id = tbs.patient_id
          SQL
        end
      end
    end
  end
end
# rubocop:enable Metrics/BlockLength
