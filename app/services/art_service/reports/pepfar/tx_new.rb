# frozen_string_literal: true

module ArtService
  module Reports
    module Pepfar
      # This class is responsible for generating the tx_new report
      class TxNew
        include ModelUtils
        include Pepfar::Utils
        attr_reader :start_date, :end_date

        def initialize(start_date:, end_date:, **_kwargs)
          @start_date = start_date.to_date.beginning_of_day.strftime('%Y-%m-%d %H:%M:%S')
          @end_date = end_date.to_date.end_of_day.strftime('%Y-%m-%d %H:%M:%S')
        end

        def find_report
          report = init_report
          process_data report
          flatten_the_report report
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

        def process_data(report)
          data.each do |row|
            age_group = row['age_group']
            gender = row['gender']
            next if age_group.blank?
            next if gender.blank?
            next unless GENDER.include?(gender)
            next unless pepfar_age_groups.include?(age_group)

            cd4_count_group = row['cd4_count_group']
            new_patient = row['new_patient'].to_i
            patient_id = row['patient_id'].to_i

            puts "Processing patient_id: #{patient_id}! #{row}"

            report[age_group.to_s][gender.to_s][cd4_count_group.to_sym] << patient_id
            report[age_group.to_s][gender.to_s]["transfer_in".to_sym] << patient_id if new_patient.zero?
          end
        end

        def flatten_the_report(report)
            result = []
            report.each do |age_group, age_group_report|
                puts "Processing age_group: #{age_group}! #{age_group_report}"
                result << {
                    age_group: age_group,
                    gender: age_group_report[0]['gender'],
                    cd4_less_than_200: age_group_report[0]['gender'][0]['cd4_less_than_200'.to_sym],
                    cd4_greater_than_equal_to_200: age_group_report[0]['gender'][0]['cd4_greater_than_equal_to_200'.to_sym],
                    cd4_unknown_or_not_done: age_group_report['gender'][0]['cd4_unknown_or_not_done'.to_sym],
                    transfer_in: age_group_report['gender'][0]['transfer_in'.to_sym]
                }
                result << {
                    age_group: age_group,
                    gender: age_group_report['gender'][1],
                    cd4_less_than_200: age_group_report['gender'][1]['cd4_less_than_200'.to_sym],
                    cd4_greater_than_equal_to_200: age_group_report['gender'][1]['cd4_greater_than_equal_to_200'.to_sym],
                    cd4_unknown_or_not_done: age_group_report['gender'][1]['cd4_unknown_or_not_done'.to_sym],
                    transfer_in: age_group_report['gender'][1]['transfer_in'.to_sym]
                }
            end
        end

        def data
          ActiveRecord::Base.connection.select_all <<~SQL
            SELECT
                pp.patient_id,
                LEFT(pe.gender, 1) gender,
                disaggregated_age_group(pe.birthdate, DATE('#{end_date}')) age_group,
                CASE
                    WHEN o.value_numeric < 200 THEN 'cd4_less_than_200'
                    WHEN o.value_numeric = 200 AND o.value_modifier = '=' THEN 'cd4_less_than_200'
                    WHEN o.value_numeric = 200 AND o.value_modifier = '<' THEN 'cd4_less_than_200'
                    WHEN o.value_numeric = 200 AND o.value_modifier = '>' THEN 'cd4_greater_than_equal_to_200'
                    WHEN o.value_numeric > 200 THEN 'cd4_greater_than_equal_to_200'
                    ELSE 'cd4_unknown_or_not_done'
                END cd4_count_group,
                CASE
                    WHEN transfer_in.value_coded IS NOT NULL THEN 0
                    ELSE 1
                END new_patient
            FROM patient_program pp
            INNER JOIN person pe ON pe.person_id = pp.patient_id AND pe.voided = 0
            LEFT JOIN (
                SELECT max(o.obs_datetime) AS obs_datetime, o.person_id
                FROM obs o
                INNER JOIN concept_name cn ON cn.concept_id = o.concept_id AND cn.name = 'CD4 count'
                INNER JOIN patient_program pp ON pp.patient_id = o.person_id
                    AND pp.program_id = #{program('HIV PROGRAM').id}
                    AND pp.voided = 0
                    AND pp.date_enrolled <= DATE('#{end_date}')
                    AND pp.date_enrolled >= DATE('#{start_date}')
                WHERE o.concept_id = #{concept_name('CD4 count').concept_id} AND o.voided = 0
                AND o.obs_datetime <= DATE('#{end_date}') AND o.obs_datetime >= DATE('#{start_date}')
                GROUP BY o.person_id
            ) current_cd4 ON current_cd4.person_id = pp.patient_id
            LEFT JOIN obs o ON o.person_id = pp.patient_id AND o.concept_id = #{concept_name('CD4 count').concept_id} AND o.voided = 0 AND o.obs_datetime = current_cd4.obs_datetime
            LEFT JOIN obs transfer_in ON transfer_in.person_id = pp.patient_id
                AND transfer_in.concept_id = #{concept_name('Ever registered at ART clinic').concept_id}
                AND transfer_in.voided = 0
                AND transfer_in.value_coded = #{concept_name('Yes').concept_id}
                AND DATE(transfer_in.obs_datetime) <= pp.date_enrolled
            WHERE pp.program_id = #{program('HIV PROGRAM').id} AND pp.voided = 0 AND pp.date_enrolled <= DATE('#{end_date}') AND pp.date_enrolled >= DATE('#{start_date}')
            GROUP BY pp.patient_id
          SQL
        end
      end
    end
  end
end
