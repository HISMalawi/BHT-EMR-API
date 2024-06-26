# rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity, Metrics/ClassLength, Style/Documentation
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
          pepfar_age_groups.each_with_object({}) do |age_group, report|
            report[age_group] = %w[Male Female Unknown].each_with_object({}) do |gender, age_group_report|
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
          arv_concept_set = ConceptName.find_by(name: 'ARVS').concept_id

          if @rebuild
            report_type = (@org.match(/pepfar/i) ? 'pepfar' : 'moh')
            ArtService::Reports::CohortBuilder\
              .new(outcomes_definition: report_type)\
              .init_temporary_tables(@start_date, @end_date, @occupation)
          end

          patients = ActiveRecord::Base.connection.select_all <<~SQL
            SELECT p.patient_id,od.quantity,d.drug_id,d.name,cm.gender,
                  TIMESTAMPDIFF(day, o.start_date, o.auto_expire_date) AS prescribed_days,
                  disaggregated_age_group(p.birthdate, '#{@end_date}') AS age_group,
                  regimens.name AS regimen
            FROM temp_earliest_start_date p
            INNER JOIN temp_patient_outcomes outcome ON outcome.patient_id = p.patient_id
              AND outcome.cum_outcome = 'On antiretrovirals'
              AND p.date_enrolled <= '#{@end_date}'
            INNER JOIN temp_cohort_members cm ON cm.patient_id = p.patient_id
            INNER JOIN orders o ON o.patient_id = p.patient_id
              AND o.voided = 0
            INNER JOIN temp_max_drug_orders tmdo ON tmdo.patient_id = p.patient_id
              AND o.start_date = tmdo.start_date
            INNER JOIN drug_order od ON od.order_id = o.order_id
              AND od.quantity > 0
            INNER JOIN drug d ON d.drug_id = od.drug_inventory_id
            INNER JOIN concept_set s ON s.concept_id = d.concept_id
              AND s.concept_set = #{arv_concept_set} AND o.voided = 0
            LEFT JOIN (
                      SELECT drug_id, regimen_name.name AS name
                      FROM moh_regimen_combination AS combo
                      INNER JOIN moh_regimen_combination_drug AS drug USING (regimen_combination_id)
                      INNER JOIN moh_regimen_name AS regimen_name USING (regimen_name_id)
                      GROUP BY combo.regimen_combination_id
                    ) AS regimens ON regimens.drug_id = d.drug_id
            GROUP BY o.order_id;
          SQL

          weights = ActiveRecord::Base.connection.select_all <<~SQL
            SELECT o.person_id patient_id, COALESCE(MAX(value_numeric), MAX(value_text)) AS weight
              FROM obs o
              INNER JOIN temp_earliest_start_date t ON t.patient_id = o.person_id#{' '}
            WHERE o.concept_id = #{concept('Weight (Kg)').concept_id}
              AND (CAST(value_numeric as DECIMAL(4,1)) > 0 OR CAST(value_text as DECIMAL(4,1)) > 0)
              AND o.obs_datetime < '#{@end_date}'
            GROUP BY o.person_id
          SQL

          ingredients = ActiveRecord::Base.connection.select_all <<~SQL
            SELECT
              r.regimen_index, i.min_weight, i.max_weight,
              i.drug_inventory_id, d.am, d.pm
            FROM moh_regimens r
            INNER JOIN moh_regimen_ingredient i ON r.regimen_id = i.regimen_id
            INNER JOIN moh_regimen_doses d ON i.dose_id = d.dose_id
            GROUP BY min_weight, max_weight, drug_inventory_id;
          SQL

          return {} if patients.blank?

          p_ids = patients.map { |a| a['patient_id'] }.uniq

          threads = ENV.fetch('RAILS_MAX_THREADS', 5).to_i
          mutex = Mutex.new

          Parallel.each(p_ids, in_threads: threads - 1) do |id|
            data = patients.select { |p| p['patient_id'] == id }
            patient_weight = weights.select { |p| p['patient_id'] == id }&.first
            regimen_index = data.first['regimen']&.to_i

            ingredient = ingredients.select do |i|
              i['min_weight'] >= patient_weight['weight'].to_f\
               && i['max_weight'] <= patient_weight['weight'].to_f\
               && i['regimen_index'] == regimen_index
            end

            age_group = data.first['age_group']
            gender = data.first['gender'] == 'M' ? 'Male' : 'Female' || 'Unknown'

            len = get_dispensing_info(data, ingredient)

            indicator = if len < 90
                          'less_than_three_months'
                        elsif len >= 90 && len <= 150
                          'three_to_five_months'
                        elsif len > 150
                          'greater_than_six_months'
                        end

            mutex.synchronize do
              report[age_group][gender][indicator.to_sym] << id
            end
          end

          report
        end

        def get_dispensing_info(data, ingredients)
          regimen = data[0]['regimen']
          prescribed_days = nil

          unless regimen&.match(/N/i)
            doses = {}
            (ingredients || []).each do |i|
              drug_id = i['drug_inventory_id'].to_i
              am = i['am'].to_f
              pm = i['pm'].to_f
              doses[drug_id] = (am.to_f + pm.to_f).to_f
            end

            unless doses.blank?
              data.each do |info|
                drug_id = info['drug_id'].to_i
                quantity = info['quantity'].to_f
                dose_per_day = doses[drug_id]
                next if dose_per_day.blank?

                if prescribed_days.blank?
                  prescribed_days = (quantity / dose_per_day).to_i
                else
                  days = (quantity / dose_per_day).to_i
                  prescribed_days = days if days > prescribed_days
                end
              end
            end

            return prescribed_days unless prescribed_days.blank?
          end

          data.each do |info|
            days = (info['prescribed_days'].to_i + 1)
            if prescribed_days.blank?
              prescribed_days = days
            elsif days > prescribed_days
              prescribed_days = days
            end
          end

          prescribed_days
        end
      end
    end
  end
end
# rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity, Metrics/ClassLength, Style/Documentation
