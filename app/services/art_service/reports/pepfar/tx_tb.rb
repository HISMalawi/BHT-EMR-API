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
          init_report
          ARTService::Reports::CohortBuilder.new(outcomes_definition: 'pepfar').init_temporary_tables(start_date, end_date)
          tx_curr = find_patients_alive_and_on_art
          tx_curr.each { |patient| report[patient['age_group']][patient['gender'].to_sym][:tx_curr] << patient['patient_id'] }
        end

        # def find_report
        #   init_report
        #   tx_curr = find_patients_alive_and_on_art
        #   tx_curr.each { |patient| report[patient['age_group']][patient['gender'].to_sym][:tx_curr] << patient['patient_id'] }
        #   screened = tb_screened(tx_curr.map { |patient| patient['patient_id'] })
        #   pepfar_age_groups.each do |age_group|
        #     screened.each do |patient|

        #       next unless patient['age_group'] == age_group

        #       start_date = patient['earliest_start_date']
        #       enrollment_date = patient['date_enrolled']
        #       tb_status_id = patient['tb_status']
        #       gender = patient['gender'].to_sym

        #       tb_status_name = ConceptName.find_by_concept_id(tb_status_id).name
        #       next unless tb_status_name.present?

        #       key_prefix = new_on_art(start_date, enrollment_date) ? :new : :prev

        #       started_tb_key = :"started_tb_#{key_prefix}"
        #       sceen_pos_key = :"sceen_pos_#{key_prefix}"
        #       sceen_neg_key = :"sceen_neg_#{key_prefix}"
        #       if ['RX', 'Confirmed TB on treatment'].include?(tb_status_name)
        #         report[age_group][gender][started_tb_key] << patient['person_id']
        #       elsif ['TB Suspected', 'Confirmed TB NOT on treatment', 'sup', 'Norx'].include?(tb_status_name)
        #         report[age_group][gender][sceen_pos_key] << patient['person_id']
        #       elsif tb_status_name == 'TB NOT suspected'
        #         report[age_group][gender][sceen_neg_key] << patient['person_id']
        #       end
        #     end
        #   end
        #   report
        # end

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

        def arv_concepts
          @arv_concepts ||= ConceptSet.where(concept_set: ConceptName.where(name: 'Antiretroviral drugs')
                                                                    .select(:concept_id))
                                      .collect(&:concept_id).join(',')
        end

        def find_patients_alive_and_on_art
          ActiveRecord::Base.connection.select_all <<~SQL
            SELECT tpo.patient_id, tesd.gender, disaggregated_age_group(tesd.birthdate, DATE('#{end_date.to_date}')) age_group
            FROM temp_patient_outcomes tpo
            INNER JOIN temp_earliest_start_date tesd ON tesd.patient_id = tpo.patient_id
            WHERE tpo.cum_outcome = 'On antiretrovirals'
          SQL
        end

        def new_on_art(earliest_start_date, min_date)
          med_start_date = min_date.to_date
          med_end_date = (earliest_start_date.to_date + 90.day).to_date

          return true if med_start_date >= earliest_start_date.to_date && med_start_date < med_end_date

          false
        end

        def clients_screened_for_tb
          ActiveRecord::Base.connecton.select_all <<~SQL
            CREATE TEMPORARY TABLE temp_tb_screened AS
            SELECT DISTINCT(o.person_id) as patient_id, MAX(o.obs_datetime) AS screened_date, tesd.enrollment_date
            FROM obs o
            INNER JOIN temp_earliest_start_date tesd ON tesd.patient_id = o.person_id
            WHERE o.concept = #{ConceptName.find_by_name('TB status').concept_id} 
            AND o.voided = 0 AND o.value_coded IN (#{ConceptName.find_by_name('TB Suspected').concept_id}, #{ConceptName.find_by_name('TB NOT suspected').concept_id})
            AND o.obs_datetime BETWEEN '#{start_date}' AND '#{end_date}'
            GROUP BY o.person_id
          SQL
        end

        def clients_confirmed_tb_and_on_treatment
          ActiveRecord::Base.connection.select_all <<~SQL
            CREATE TEMPORARY TABLE temp_tb_confirmed_and_on_treatment AS
            SELECT o.person_id, MAX(o.obs_datetime) AS obs_datetime
            FROM obs o
            WHERE o.concept = #{ConceptName.find_by_name('TB status').concept_id}
            AND o.value_coded = #{ConceptName.find_by_name('Confirmed TB on treatment').concept_id}
            AND o.voided = 0
            AND o.obs_datetime BETWEEN '#{start_date}' AND '#{end_date}'
            AND o.person_id IN(SELECT patient_id FROM temp_tb_screened)
            GROUP BY o.person_id
          SQL
        end

        def tb_screened(patient_ids)
          return [] if patient_ids.blank?

          ActiveRecord::Base.connection.select_all <<~SQL
            SELECT DISTINCT p.person_id, p.gender, o.value_coded AS tb_status, disaggregated_age_group(p.birthdate, DATE(#{ActiveRecord::Base.connection.quote(end_date.to_date)})) AS age_group, earliest_start_date_at_clinic(p.person_id) AS earliest_start_date,
            date_antiretrovirals_started(p.person_id, DATE(#{ActiveRecord::Base.connection.quote(end_date.to_date)})) AS date_enrolled
            FROM person p
            INNER JOIN obs o ON o.person_id = p.person_id and o.voided = 0
            WHERE o.concept_id = #{ConceptName.find_by_name('TB status').concept_id}
            AND p.person_id IN(#{patient_ids.join(",")})
          SQL
        end
      end
    end
  end
end
# rubocop:enable Metrics/BlockLength
