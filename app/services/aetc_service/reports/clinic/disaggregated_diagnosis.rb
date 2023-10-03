# frozen_string_literal: true

module AetcService
  module Reports
    module Clinic
      # This report is for the disaggregated diagnosis report
      class DisaggregatedDiagnosis
        include ModelUtils
        attr_reader :start_date, :end_date

        def initialize(start_date:, end_date:, **_kwargs)
          @start_date = start_date.to_date.beginning_of_day.strftime('%Y-%m-%d %H:%M:%S')
          @end_date = end_date.to_date.end_of_day.strftime('%Y-%m-%d %H:%M:%S')
        end

        def fetch_report
          # TODO: Add disaggregated diagnosis report
        end

        private

        GENDER = %w[M F UNKNOWN].freeze
        AGE_GROUPS = ['< 6 months', '6 months to < 5', '5 to 14', '> 14', 'total_by_gender'].freeze

        def diagnosis_report
          ActiveRecord::Base.connection.select_all <<~SQL
            SELECT
                cn.name diagnosis,
                COALESCE(LEFT(p.gender, 1), 'UNKNOWN'),
                p.person_id patient_id,
                CASE
                    WHEN timestampdiff(month, pe.birthdate, '#{end_date}') < 6 THEN '< 6 months'
                    WHEN timestampdiff(month, pe.birthdate, '#{end_date}') >= 6 AND timestampdiff(month, pe.birthdate, '#{end_date}') < 60 THEN '6 months to < 5'
                    WHEN timestampdiff(month, pe.birthdate, '#{end_date}') >= 60 AND timestampdiff(month, pe.birthdate, '#{end_date}') < 168 THEN '5 to 14'
                    WHEN timestampdiff(month, pe.birthdate, '#{end_date}') >= 168 THEN '> 14'
                END age_group
            FROM person p
            INNER JOIN encounter e ON e.patient_id = p.person_id
                AND e.voided = 0
                AND e.encounter_type = #{encounter_type('diagnosis').encounter_type_id}
                AND e.encounter_datetime >= '#{start_date}' AND e.encounter_datetime <= '#{end_date}'
                AND e.program_id = #{program('AETC PROGRAM').program_id}
            INNER JOIN obs o ON o.encounter_id = e.encounter_id
                AND o.voided = 0
                AND o.concept_id IN (#{concept('PRIMARY DIAGNOSIS').concept_id}, #{concept('SECONDARY DIAGNOSIS').concept_id})
                AND o.obs_datetime >= '#{start_date}' AND o.obs_datetime <= '#{end_date}'
            INNER JOIN concept_name cn ON cn.concept_id = o.value_coded AND cn.voided = 0
            WHERE p.voided = 0
            GROUP BY o.value_coded, p.person_id
          SQL
        end

        # rubocop:disable Metrics/AbcSize
        def process_diagnosis_report
          report_data = {}
          diagnosis_report.each do |diag|
            next unless diag['diagnosis']
            next unless diag['age_group']

            report_data[diag['diagnosis']] = init_age_group_gender_hash unless report_data.key?(diag['diagnosis'])
            report_data[diag['diagnosis']][diag['age_group']][diag['gender']].push(diag['patient_id'])
            report_data[diag['diagnosis']]['total_by_gender'][diag['gender']].push(diag['patient_id'])
          end
          report_data
        end
        # rubocop:enable Metrics/AbcSize

        def init_age_group_gender_hash
          @init_age_group_gender_hash ||= AGE_GROUPS.each_with_object({}) do |age_group, report|
            report[age_group] = GENDER.each_with_object({}) do |gender, subreport|
              subreport[gender] = []
            end
          end
        end
      end
    end
  end
end
