# frozen_string_literal: true

module ARTService
  module Reports
    module Pepfar
      # This class is responsible for generating the tx_new report
      class TxNew
        include ModelUtils
        include Pepfar::Utils
        attr_reader :start_date, :end_date, :current_location

        def initialize(start_date:, end_date:, **_kwargs)
          @start_date = start_date.to_date.beginning_of_day.strftime('%Y-%m-%d %H:%M:%S')
          @end_date = end_date.to_date.end_of_day.strftime('%Y-%m-%d %H:%M:%S')
          @current_location = Location.current_health_center&.name&.downcase
        end

        def find_report
          report = init_report
          addittional_groups report
          process_data report
          flatten_the_report report
        rescue StandardError => e
          Rails.logger.error e.message
          Rails.logger.error e.backtrace.join("\n")

          raise e
        end

        private

        GENDER = %w[M F].freeze

        def init_report
          pepfar_age_groups.each_with_object({}) do |age_group, report|
            report[age_group] = GENDER.each_with_object({}) do |gender, age_group_report|
              age_group_report[gender] = {
                cd4_less_than_200: [],
                cd4_greater_than_equal_to_200: [],
                cd4_unknown_or_not_done: [],
                transfer_in: []
              }
            end
          end
        end

        def addittional_groups(report)
          report['All'] = {}
          %w[Male FP FNP FBf].each do |key|
            report['All'][key] = {
              cd4_less_than_200: [],
              cd4_greater_than_equal_to_200: [],
              cd4_unknown_or_not_done: [],
              transfer_in: []
            }
          end
        end

        def process_data(report)
          data.each do |row|
            age_group = row['age_group']
            gender = row['gender']
            date_enrolled = row['date_enrolled']
            next if age_group.blank?
            next if gender.blank?
            next unless GENDER.include?(gender)
            next unless pepfar_age_groups.include?(age_group)

            cd4_count_group = row['cd4_count_group']
            new_patient = row['new_patient'].to_i
            patient_id = row['patient_id'].to_i
            earliest_start_date = row['earliest_start_date']
            indicator = new_patient.positive? ? cd4_count_group : 'transfer_in'
            art_initiation_location = row['art_initiation_location']&.downcase

            if new_patient.positive? && earliest_start_date.to_date >= start_date.to_date
              report[age_group.to_s][gender.to_s][indicator.to_sym] << patient_id 
            elsif new_patient.zero? && art_initiation_location != current_location
              report[age_group.to_s][gender.to_s][indicator.to_sym] << patient_id
            else
              next
            end
            process_aggreggation_rows(report: report, gender: gender, indicator: indicator, start_date: date_enrolled, patient_id: patient_id, maternal_status: row['maternal_status'], maternal_status_date: row['maternal_status_date'])
          end
        end

        def process_aggreggation_rows(report:, gender:, indicator:, start_date:, **kwargs)
          maternal_status = kwargs[:maternal_status]
          maternal_status_date = kwargs[:maternal_status_date]

          if gender == 'M'
            report['All']['Male'][indicator.to_sym] << kwargs[:patient_id]
          elsif maternal_status&.match?(/pregnant/i) && maternal_status_date&.to_date <= start_date.to_date
            report['All']['FP'][indicator.to_sym] << kwargs[:patient_id]
          elsif maternal_status&.match?(/breast/i) && maternal_status_date&.to_date <= start_date.to_date
            report['All']['FBf'][indicator.to_sym] << kwargs[:patient_id]
          else
            report['All']['FNP'][indicator.to_sym] << kwargs[:patient_id]
          end
        end

        def process_age_group_report(age_group, gender, age_group_report)
          {
            age_group: age_group,
            gender: if gender == 'F'
                      'Female'
                    else
                      (gender == 'M' ? 'Male' : gender)
                    end,
            cd4_less_than_200: age_group_report['cd4_less_than_200'.to_sym],
            cd4_greater_than_equal_to_200: age_group_report['cd4_greater_than_equal_to_200'.to_sym],
            cd4_unknown_or_not_done: age_group_report['cd4_unknown_or_not_done'.to_sym],
            transfer_in: age_group_report['transfer_in'.to_sym]
          }
        end

        def flatten_the_report(report)
          result = []
          report.each do |age_group, age_group_report|
            age_group_report.each_key do |gender|
              result << process_age_group_report(age_group, gender, age_group_report[gender])
            end
          end

          new_group = pepfar_age_groups.map { |age_group| age_group }
          new_group << 'All'
          gender_scores = { 'Female' => 0, 'Male' => 1, 'FNP' => 3, 'FP' => 2, 'FBf' => 4 }
          result_scores = result.sort_by do |item|
            gender_score = gender_scores[item[:gender]]
            age_group_score = new_group.index(item[:age_group])
            [gender_score, age_group_score]
          end
          # remove all unknown age groups
          result_scores.reject { |item| item[:age_group].match?(/unknown/i) }
        end

        def data
          ActiveRecord::Base.connection.select_all <<~SQL
            SELECT
                pp.patient_id,
                LEFT(pe.gender, 1) gender,
                disaggregated_age_group(pe.birthdate, DATE('#{end_date}')) age_group,
                CASE
                    WHEN o.value_numeric < 200 THEN 'cd4_less_than_200'
                    WHEN o.value_numeric = 200 AND o.value_modifier = '=' THEN 'cd4_greater_than_equal_to_200'
                    WHEN o.value_numeric = 200 AND o.value_modifier = '<' THEN 'cd4_less_than_200'
                    WHEN o.value_numeric = 200 AND o.value_modifier = '>' THEN 'cd4_greater_than_equal_to_200'
                    WHEN o.value_numeric > 200 THEN 'cd4_greater_than_equal_to_200'
                    ELSE 'cd4_unknown_or_not_done'
                END cd4_count_group,
                CASE
                    WHEN transfer_in.value_coded IS NOT NULL THEN 0
                    ELSE 1
                END new_patient,
                MIN(ps.start_date) date_enrolled,
                DATE(COALESCE(art_start_date.value_datetime, MIN(ord.start_date))) earliest_start_date,
                preg_or_breast.name AS maternal_status,
                DATE(MIN(pregnant_or_breastfeeding.obs_datetime)) AS maternal_status_date,
                art_initiation_location.value_text AS art_initiation_location
            FROM patient_program pp
            INNER JOIN person pe ON pe.person_id = pp.patient_id AND pe.voided = 0
            INNER JOIN patient_state ps ON ps.patient_program_id = pp.patient_program_id AND ps.voided = 0 AND ps.start_date >= '#{start_date}' AND ps.start_date <= '#{end_date}' AND ps.state = 7   -- ON ART
            INNER JOIN orders ord ON ord.patient_id = pp.patient_id AND ord.voided = 0 AND ord.start_date <= '#{end_date}' AND ord.order_type_id = #{order_type('Drug Order').id}
            INNER JOIN drug_order do ON do.order_id = ord.order_id AND do.quantity > 0 AND do.drug_inventory_id IN (SELECT drug_id FROM arv_drug)
            LEFT JOIN obs art_start_date ON art_start_date.person_id = pp.patient_id AND art_start_date.concept_id = #{concept_name('ART start date').concept_id} AND art_start_date.voided = 0
            LEFT JOIN (
                SELECT max(o.obs_datetime) AS obs_datetime, o.person_id
                FROM obs o
                INNER JOIN concept_name cn ON cn.concept_id = o.concept_id AND cn.name = 'CD4 count' AND cn.voided = 0
                INNER JOIN patient_program pp ON pp.patient_id = o.person_id
                    AND pp.program_id = #{program('HIV PROGRAM').id}
                    AND pp.voided = 0
                INNER JOIN patient_state ps ON ps.patient_program_id = pp.patient_program_id AND ps.voided = 0 AND ps.state = 7 AND ps.start_date <= DATE('#{end_date}') AND ps.start_date >= DATE('#{start_date}')
                WHERE o.concept_id = #{concept_name('CD4 count').concept_id} AND o.voided = 0
                AND o.obs_datetime <= '#{end_date}' AND o.obs_datetime >= '#{start_date}'
                GROUP BY o.person_id
            ) current_cd4 ON current_cd4.person_id = pp.patient_id
            LEFT JOIN obs o ON o.person_id = pp.patient_id AND o.concept_id = #{concept_name('CD4 count').concept_id} AND o.voided = 0 AND o.obs_datetime = current_cd4.obs_datetime
            LEFT JOIN obs transfer_in ON transfer_in.person_id = pp.patient_id
                AND transfer_in.concept_id = #{concept_name('Ever registered at ART clinic').concept_id}
                AND transfer_in.voided = 0
                AND transfer_in.value_coded = #{concept_name('Yes').concept_id}
                AND DATE(transfer_in.obs_datetime) <= '#{end_date}'
                AND DATE(transfer_in.obs_datetime) >= '#{start_date}'
            LEFT JOIN obs art_initiation_location ON art_initiation_location.person_id = transfer_in.person_id AND art_initiation_location.concept_id = #{concept_name('Location of ART initiation').concept_id} AND art_initiation_location.voided = 0
            LEFT JOIN obs pregnant_or_breastfeeding ON pregnant_or_breastfeeding.person_id = pp.patient_id
              AND pregnant_or_breastfeeding.concept_id IN (SELECT concept_id FROM concept_name WHERE name IN ('Breast feeding?', 'Breast feeding', 'Breastfeeding', 'Is patient pregnant?', 'patient pregnant') AND voided = 0)
              AND pregnant_or_breastfeeding.voided = 0
              AND pregnant_or_breastfeeding.value_coded = #{concept_name('Yes').concept_id}
            LEFT JOIN concept_name preg_or_breast ON preg_or_breast.concept_id = pregnant_or_breastfeeding.concept_id AND preg_or_breast.voided = 0
            WHERE pp.program_id = #{program('HIV PROGRAM').id} AND pp.voided = 0 -- AND pp.date_enrolled <= DATE('#{end_date}') AND pp.date_enrolled >= DATE('#{start_date}') ** This was removed because some people do hacks to the system **
            GROUP BY pp.patient_id
            HAVING date_enrolled <= '#{end_date}' AND date_enrolled >= '#{start_date}'
          SQL
        end
      end
    end
  end
end
