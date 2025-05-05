# frozen_string_literal: true

module ArtService
  module Reports
    module Clinic
      class HtnEnrollment < CachedReport
        attr_reader :start_date, :end_date, :dsd, :report

        def initialize(start_date:, end_date:, **kwargs)
          super(start_date:, end_date:, definition: 'moh', **kwargs)
          @start_date = start_date.to_date
          @end_date = end_date.to_date
        end

        PERIODS = {
          cummulative: [],
          reporting_period: []
        }.freeze

        def report_struct
          {
            htn_enrollment: enrollment_struct,
            treatment_drug_classification: treatment_drug_classification_struct
          }.freeze
        end

        def find_report
          @report = report_struct.deep_dup
          diagnosed_with_htn = all_patients_diagnosed_with_htn
          lts_visits = patient_latest_visits(diagnosed_with_htn.map { |p| p['patient_id'] })&.to_a

          diagnosed_with_htn.each do |p|

            patient_id = p['patient_id']

            patient = p.merge(lts_visits&.find { |a| a['patient_id'] == patient_id } || {})
            date_diagonised = patient['date_diagonised']&.to_date

            PERIODS.each_key do |period|
              next if period === :reporting_period && !within_reporting_period?(date_diagonised)

              process_enrollement_data(patient, period)
              process_treatment_drug_classification(p, period)
            end
          end

          report
        end

        def process_enrollement_data(patient, period)
          key = :htn_enrollment
          patient_id = patient['patient_id']
          date_diagonised = patient.fetch('date_diagonised', nil)&.to_date
          lts_visit_date = patient.fetch('lts_visit_date', nil)&.to_date
          lts_systolic = patient.fetch('lts_systolic', nil)&.to_i
          lts_diastolic = patient.fetch('lts_diastolic', nil)&.to_i
          moh_cum_outcome = patient.fetch('moh_cum_outcome')

          report[key][:registered_with_hypertension][period] << patient_id

          
          if moh_cum_outcome === 'on antiretrovirals'
            report[key][:enrolled_and_active_in_care][period] << patient_id
          end
          
          if moh_cum_outcome === 'defaulted'
            report[key][:who_have_defaulted_during_the_reporting_period][period] << patient_id
          end
          
          report[key][:who_have_died][period] << patient_id if moh_cum_outcome === 'patient died'
          report[key][:who_have_transferred_out][period] << patient_id if moh_cum_outcome === 'patient transferred out'
          report[key][:who_have_stopped_htn_care][period] << patient_id if moh_cum_outcome === 'treatment stopped'
                    
          if lts_visit_date.present?
            report[key][:with_a_visit_in_last_3_months][period] << patient_id
          end

          if lts_visit_date.present? && lts_systolic.present? && lts_diastolic.present?
            report[key][:with_a_visit_in_last_3_months_who_have_a_bp_measurement_recorded][period] << patient_id
          end

          if lts_visit_date.present? && lts_systolic.present? && lts_diastolic.present? && lts_systolic < 140 && lts_diastolic < 90
            report[key][:with_a_visit_in_last_3_months_who_have_bp_below_140_90][period] << patient_id
          end
        end

        def process_treatment_drug_classification(patient, period)
          key = :treatment_drug_classification

          patient_id = patient['patient_id']
          drugs = patient['drugs']&.split(',') || []

          drug_category_mapping.each do |category, drugs_list|
            next if report[key][category][period].include?(patient_id)

            report[key][category][period] << patient_id if drugs_list.any? { |d| drugs.include?(d) }
            
            return if report[key][:others][period].include?(patient_id)
            
            report[key][:others][period] << patient_id if drugs.length > 0 && drugs.all? { |d| !drugs_list.include?(d) }
          end
        end

        def enrollment_struct
          {
            registered_with_hypertension: deep_clone_periods,
            enrolled_and_active_in_care: deep_clone_periods,
            who_have_defaulted_during_the_reporting_period: deep_clone_periods,
            who_have_died: deep_clone_periods,
            who_have_transferred_out: deep_clone_periods,
            who_have_stopped_htn_care: deep_clone_periods,
            with_a_visit_in_last_3_months: deep_clone_periods,
            with_a_visit_in_last_3_months_who_have_a_bp_measurement_recorded: deep_clone_periods,
            with_a_visit_in_last_3_months_who_have_bp_below_140_90: deep_clone_periods
          }.freeze
        end

        def deep_clone_periods
          PERIODS.deep_dup.transform_values { [] }
        end

        def treatment_drug_classification_struct
          {
            diuretics: [],
            beta_blockers: [],
            calcium_channel_blockers: [],
            ace_inhibitors: [],
            angiotensin_2_receptor_blockers: [],
            vasodilator: [],
            others: []
          }.transform_values { |_v| PERIODS }&.freeze
        end

        def drug_category_mapping
          {
            diuretics: %w[hctz frusemide spironolactone bendrofluazide],
            beta_blockers: %w[atenolol carvedilol propranolol bisoprolol],
            calcium_channel_blockers: %w[amlodipine nifedipine],
            ace_inhibitors: %w[enalapril captopril lisinopril perindopril],
            angiotensin_2_receptor_blockers: %w[losartan valsartan olmesartan telmisartan],
            vasodilator: %w[hydralazine],
            others: %w[]
          }.freeze
        end

        def within_reporting_period?(date_diagonised)
          date_diagonised ||= start_date - 1.year
          date_diagonised >= start_date
        end

        def all_patients_diagnosed_with_htn
          ActiveRecord::Base.connection.select_all <<~SQL
            SELECT hp.patient_id,
                DATE(diagonised.value_datetime) AS date_diagonised,
                treatment.drugs,
                LOWER(tpo.moh_cum_outcome) AS moh_cum_outcome,
                tpo.moh_outcome_date
            FROM encounter hp
            INNER JOIN obs diagonised ON diagonised.encounter_id = hp.encounter_id
                  AND diagonised.voided = 0
                  AND diagonised.concept_id = #{concept('Hypertension diagnosis date').id}
            LEFT JOIN (
                SELECT o.patient_id,#{' '}
                    o.date_created,
                    o.encounter_id,
                    GROUP_CONCAT(DISTINCT LOWER(c.name)) AS drugs
                FROM orders o
                INNER JOIN concept_name c ON c.concept_id = o.concept_id
                WHERE o.voided = 0
                  AND c.concept_id IN (#{Drug.bp_drugs.map(&:id).join(',')})
                GROUP BY patient_id
            ) treatment ON treatment.date_created >= diagonised.obs_datetime
            LEFT JOIN temp_patient_outcomes tpo ON tpo.patient_id = hp.patient_id
            WHERE hp.program_id = #{program('HIV Program').id}
              AND hp.voided = 0
              AND DATE(hp.encounter_datetime) <= #{ActiveRecord::Base.connection.quote(end_date)}
            GROUP BY patient_id
          SQL
        end

        def patient_latest_visits(patient_ids)
          ActiveRecord::Base.connection.select_all <<~SQL
            SELECT
              lts_systolic.person_id AS patient_id,
              lts_systolic.value_numeric AS lts_systolic,
              lts_diastolic.value_numeric AS lts_diastolic,
              DATE(e.encounter_datetime) AS lts_visit_date
            FROM encounter e 
            LEFT JOIN obs lts_systolic ON lts_systolic.voided = 0
              AND lts_systolic.person_id = e.patient_id
              AND lts_systolic.concept_id = #{concept('Systolic blood pressure').id}
            LEFT JOIN obs lts_diastolic ON lts_diastolic.person_id = lts_systolic.person_id
              AND lts_diastolic.voided = 0
              AND lts_diastolic.concept_id = #{concept('Diastolic blood pressure').id}
            WHERE e.patient_id IN (#{patient_ids.push(0).join(',')})
              AND DATE(e.encounter_datetime) BETWEEN DATE('#{start_date - 3.months}') AND DATE('#{end_date}')
              AND e.encounter_type = #{encounter_type('VITALS').id}
              AND e.program_id = #{program('HIV Program').id}
            GROUP BY e.patient_id
          SQL
        end
      end
    end
  end
end
