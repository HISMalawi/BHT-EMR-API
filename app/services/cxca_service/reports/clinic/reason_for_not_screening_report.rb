# frozen_string_literal: true

module CXCAService
  module Reports
    module Clinic
      # Reason for not screening report
      class ReasonForNotScreeningReport
        include Utils
        include ModelUtils
        def initialize(start_date:, end_date:)
          @start_date = start_date.to_date.beginning_of_day.strftime('%Y-%m-%d %H:%M:%S')
          @end_date = end_date.to_date.end_of_day.strftime('%Y-%m-%d %H:%M:%S')
        end

        def data
          process_report
        rescue StandardError => e
          Rails.logger.error e.message
          Rails.logger.error e.backtrace.join("\n")
          raise e
        end

        private

        def process_report
          (fetch_query || []).each do |row|
            age_group = row['age_group']
            next unless moh_age_groups.include?(age_group)

            screened = row['screening_method'].present? ? 'screened' : 'not_screened'
            if screened == 'screened'
              @report[age_group][screened][row['screening_method']] ||= 0
              @report[age_group][screened][row['screening_method']] << row['person_id']
            else
              @report[age_group][screened][row['reason_for_not_screening']] ||= 0
              @report[age_group][screened][row['reason_for_not_screening']] << row['person_id']
            end
          end
        end

        def init_report
          @report = {}
          moh_age_groups.collect do |age_group|
            @report[age_group] = {}
            @report[age_group]['screened'] = {}
            @report[age_group]['not_screened'] = {}
          end
        end

        def fetch_query
          ActiveRecord::Base.connection.select_all <<~SQL
            SELECT
              cxca_moh_age_group(p.birthdate, DATE('#{@end_date}')) age_group,
              p.person_id,
              offer_screening.value_coded offered_screening,
              reason_name.name reason_for_not_screening,
              screening_name.name screening_method
            FROM person p
            INNER JOIN (
                SELECT e.patient_id, DATE(MAX(e.encounter_datetime)) AS visit_date
                FROM encounter e
                WHERE e.program_id = #{program('HIV PROGRAM').id}
                    AND e.encounter_datetime >= '#{@start_date}'
                    AND e.encounter_datetime <= '#{@end_date}'
                    AND e.voided = 0
                    AND e.encounter_type = #{encounter_type('HIV CLINIC CONSULTATION').id}
                GROUP BY e.patient_id
            ) AS last_visit ON last_visit.patient_id = p.person_id
            LEFT JOIN obs offer_screening ON offer_screening.person_id = last_visit.patient_id
                AND offer_screening.voided = 0
                AND offer_screening.concept_id = #{concept('Offer CxCa').concept_id}
                AND DATE(offer_screening.obs_datetime) = last_visit.visit_date
            LEFT JOIN obs reason_for_not_screening ON reason_for_not_screening.person_id = last_visit.patient_id
                AND reason_for_not_screening.voided = 0
                AND reason_for_not_screening.concept_id = #{concept('Reason for NOT offering CxCa').concept_id}
                AND DATE(reason_for_not_screening.obs_datetime) = last_visit.visit_date
            LEFT JOIN concept_name reason_name ON reason_name.concept_id = reason_for_not_screening.value_coded
                AND reason_name.voided = 0
            LEFT JOIN obs cervical_cancer_screening ON cervical_cancer_screening.person_id = last_visit.patient_id
                AND cervical_cancer_screening.voided = 0
                AND cervical_cancer_screening.concept_id = #{concept('CxCa screening method').concept_id}
                AND DATE(cervical_cancer_screening.obs_datetime) = last_visit.visit_date
            LEFT JOIN concept_name screening_name ON screening_name.concept_id = cervical_cancer_screening.value_coded
                AND screening_name.voided = 0
            WHERE p.voided = 0 AND LEFT(p.gender, 1) = 'F'
            GROUP BY p.person_id
          SQL
        end
      end
    end
  end
end
