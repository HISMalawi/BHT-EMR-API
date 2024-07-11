# rubocop:disable Metrics/MethodLength, Style/Documentation, Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Metrics/BlockLength
# frozen_string_literal: true

module OpdService
  module Reports
    class OpdDisaggregated
      attr_accessor :start_date, :end_date, :report

      include ModelUtils

      AGE_IN_MONTHS_MAP = [
        '0-5 months',
        '6 mth < 5 yrs',
        '5-14 yrs',
        '>= 14 years'
      ].freeze

      def find_report(start_date:, end_date:, **_extra_kwargs)
        @start_date = start_date.to_date.beginning_of_day.strftime('%Y-%m-%d %H:%M:%S')
        @end_date = end_date.to_date.end_of_day.strftime('%Y-%m-%d %H:%M:%S')
        @report = fmt

        process
      end

      def fmt
        AGE_IN_MONTHS_MAP.each_with_object({}) do |age_group, r|
          r[age_group] = %w[M F].each_with_object({}) do |g, gr|
            gr[g] = {
              total: [],
              prev_pos_not_on_art: [],
              prev_pos_on_art: [],
              prev_neg: [],
              new_neg: [],
              new_pos: [],
              not_done: [],
              screened: [],
              not_screened: []
            }
          end
        end
      end

      def process
        patients = ActiveRecord::Base.connection.select_all <<~SQL
          SELECT opd_disaggregated_age_group(pe.birthdate, '#{end_date}') AS age_group,
            pe.gender,
            p.patient_id,
            hiv_status.value_text hiv_status,
            tst_date.value_datetime test_date,
            date_started_art.value_datetime date_started_art,
            MIN(reg_date.encounter_datetime) registration_date,
            started_art.value_coded started_art
              FROM encounter e
              INNER JOIN person pe ON pe.person_id = e.patient_id
                  AND pe.voided = 0
              INNER JOIN patient p ON p.patient_id = e.patient_id
                  AND p.voided = 0
              LEFT JOIN encounter reg_date ON reg_date.patient_id = e.patient_id
                  AND reg_date.encounter_type = #{EncounterType.find_by_name('PATIENT REGISTRATION').encounter_type_id}
                  AND reg_date.voided = 0
              LEFT JOIN obs hiv_status ON hiv_status.person_id = e.patient_id
                  AND hiv_status.voided = 0
                  AND hiv_status.concept_id = #{concept('HIV Status').concept_id}
              LEFT JOIN obs tst_date ON tst_date.encounter_id = hiv_status.encounter_id
                  AND tst_date.concept_id = #{concept('HIV test date').concept_id}
                  AND tst_date.voided = 0
              LEFT JOIN obs started_art ON started_art.encounter_id = hiv_status.encounter_id
                  AND started_art.concept_id = #{concept('ART started').concept_id}
                  AND started_art.voided = 0
              LEFT JOIN obs date_started_art ON date_started_art.encounter_id = hiv_status.encounter_id
                  AND date_started_art.concept_id = #{concept('Date antiretrovirals started').concept_id}
                  AND date_started_art.voided = 0
            WHERE e.program_id = #{Program.find_by_name('OPD program').program_id}
            AND reg_date.encounter_datetime >= '#{start_date}' AND reg_date.encounter_datetime <= '#{end_date}'
            AND e.voided = 0
            GROUP BY e.patient_id
        SQL

        process_results(patients)
      end

      def process_results(patients)
        patients.each do |p|
          reactive = concept('Reactive').concept_id
          non_reactive = concept('Non-reactive').concept_id
          unknown = concept('Unknown').concept_id

          patient_id = p['patient_id']
          age_group = p['age_group']
          gender = p['gender']
          hiv_status = concept(p['hiv_status'])&.concept_id || nil
          date_started_art = p['date_started_art']&.to_date || p['test_date']&.to_date
          opd_reg_date = p['registration_date']&.to_date
          started_art = p['started_art']

          report[age_group][gender][:total] << patient_id
          unless hiv_status.nil?
            if hiv_status == reactive
              if date_started_art <= opd_reg_date
                report[age_group][gender][:new_pos] << patient_id
              elsif date_started_art > opd_reg_date && started_art == concept('No').concept_id
                report[age_group][gender][:prev_pos_not_on_art] << patient_id
              elsif date_started_art > opd_reg_date && started_art == concept('Yes').concept_id
                report[age_group][gender][:prev_pos_on_art] << patient_id
              end
            elsif hiv_status == non_reactive && date_started_art > opd_reg_date
              report[age_group][gender][:new_neg] << patient_id
            elsif hiv_status == non_reactive && date_started_art <= opd_reg_date
              report[age_group][gender][:prev_neg] << patient_id
            elsif hiv_status == unknown
              report[age_group][gender][:not_done] << patient_id
            end
          end
          report[age_group][gender][:not_done] << patient_id if [nil, unknown].any?(hiv_status)
        end

        report
      end
    end
  end
end

# rubocop:enable Metrics/MethodLength, Style/Documentation, Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Metrics/BlockLength
