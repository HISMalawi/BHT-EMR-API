# frozen_string_literal: true
module CXCAService
  module Reports
    module Pepfar
      class CxcaScrn
        attr_reader :start_date, :end_date, :report
        CxCa_PROGRAM = Program.find_by_name "CxCa program"


        include Utils
        include ModelUtils

        CxCa_PROGRAM = 'CxCa program'

        TX_GROUPS = {
          first_time_screened: ['initial screening', 'referral'],
          rescreened_after_prev_visit: ['subsequent screening'],
          post_treatment_followup: ['one year subsequent check-up after treatment', 'problem visit after treatment']
        }.freeze

        CxCa_TX_OUTCOMES = {
          positive: ['via positive', 'hpv positive', 'pap smear abnormal', 'visible lesion'],
          negative: ['via negative', 'hpv negative', 'pap smear normal', 'no visible lesion', 'other gynae'],
          suspected: ['suspect cancer']
        }.freeze

        def initialize(start_date:, end_date:)
          @start_date = start_date.to_date.beginning_of_day
          @end_date = end_date.to_date.end_of_day
          @report = {}
        end

        def data
          init_report
        rescue StandardError => e
          Rails.logger.error e.message
          Rails.logger.error e.backtrace.join("\n")
          raise e
        end

        private

        def init_report
          query = fetch_query.to_a
          pepfar_age_groups.collect do |age_group|
            row = {}
            row['age_group'] = age_group
            TX_GROUPS.each do |(name, values)|
              screened = query.select { |q| q['reason_for_visit']&.strip&.downcase&.in?(values) && q['age_group'] == age_group }
              row[name] = {}
              CxCa_TX_OUTCOMES.each do |(outcome, values)|
                row[name][outcome] = screened.select { |s| s['treatment']&.strip&.downcase&.in?(values) }.map { |t| t['person_id'] }.uniq
              end
            end
            row
          end
        end

        def fetch_query
          ActiveRecord::Base.connection.select_all <<~SQL
            SELECT
              p.person_id,
              disaggregated_age_group(p.birthdate, '#{@end_date}') age_group,
              reason_name.name reason_for_visit,
              screening_name.name treatment
            FROM person p
            INNER JOIN (
              SELECT e.patient_id, DATE(MAX(e.encounter_datetime)) AS last_visit_date
              FROM encounter e
              WHERE e.program_id = #{program(CxCa_PROGRAM).id}
                AND e.encounter_datetime >= '#{@start_date}'
                AND e.encounter_datetime <= '#{@end_date}'
                AND e.voided = 0
              GROUP BY e.patient_id
            ) AS last_visit ON last_visit.patient_id = p.person_id
            LEFT JOIN obs reason_for_visit ON reason_for_visit.person_id = last_visit.patient_id
              AND reason_for_visit.voided = 0
              AND reason_for_visit.concept_id = #{concept('Reason for visit').concept_id}
              AND DATE(reason_for_visit.obs_datetime) = last_visit.last_visit_date
            LEFT JOIN obs treatment ON treatment.person_id = last_visit.patient_id
              AND treatment.voided = 0
              AND treatment.concept_id = #{concept('Screening results').concept_id}
              AND DATE(treatment.obs_datetime) = last_visit.last_visit_date
            LEFT JOIN concept_name reason_name ON reason_name.concept_id = reason_for_visit.value_coded
              AND reason_name.voided = 0
            LEFT JOIN concept_name screening_name ON screening_name.concept_id = treatment.value_coded
              AND screening_name.voided = 0
            INNER JOIN (
              SELECT o.patient_id
              FROM orders o
              INNER JOIN drug_order d ON d.order_id = o.order_id AND d.drug_inventory_id IN (SELECT drug_id FROM arv_drug) AND d.quantity > 0
              GROUP BY o.patient_id
            ) in_art ON in_art.patient_id = p.person_id
            WHERE p.voided = 0 AND LEFT(p.gender, 1) = 'F'
            GROUP BY p.person_id
          SQL
        end
      end
    end
  end
end
