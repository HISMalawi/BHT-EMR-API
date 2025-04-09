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
          @report = report_struct
          all_patients_diagnosed_with_htn.each do |patient|
            date_diagonised = patient['date_diagonised']&.to_date

            PERIODS.each_key do |period|
              next if period == :reporting_period && !within_reporting_period?(date_diagonised)

              process_enrollement_data(patient, period)
              process_treatment_drug_classification(patient, period)
            end
          end

          report
        end

        def process_enrollement_data(patient, period)
          key = :htn_enrollment
          patient_id = patient['patient_id']
          patient['date_screened']
          date_diagonised = patient['date_diagonised']&.to_date
          lts_visit_date = patient['lts_visit_date']&.to_date
          lts_systolic = patient['lts_systolic']
          lts_diastolic = patient['lts_diastolic']
          moh_cum_outcome = patient['moh_cum_outcome']
          patient['moh_outcome_date']&.to_date

          report[key][:registered_with_hypertension][period] << patient_id

          return if date_diagonised.nil?

          if moh_cum_outcome == 'On antiretrovirals' && date_diagonised.present?
            report[key][:enrolled_and_active_in_care][period] << patient_id
          end

          if moh_cum_outcome == 'Defaulted'
            report[key][:who_have_defaulted_during_the_reporting_period][period] << patient_id
          end

          report[key][:who_have_died][period] << patient_id if moh_cum_outcome == 'Patient died'
          report[key][:who_have_transferred_out][period] << patient_id if moh_cum_outcome == 'Transferred out'
          report[key][:who_have_stopped_htn_care][period] << patient_id if moh_cum_outcome == 'Treatment stopped'

          if lts_visit_date.present? && lts_visit_date >= (start_date - 3.months)
            report[key][:with_a_visit_in_last_3_months][period] << patient_id
          end

          if lts_visit_date.present? && lts_visit_date >= (start_date - 3.months) && lts_systolic.present? && lts_diastolic.present?
            report[key][:with_a_visit_in_last_3_months_who_have_a_bp_measurement_recorded][period] << patient_id
          end

          if lts_visit_date.present? && lts_visit_date >= (start_date - 3.months) && lts_systolic.present? && lts_diastolic.present? && lts_systolic < 140 && lts_diastolic < 90
            report[key][:with_a_visit_in_last_3_months_who_have_bp_below_140_90][period] << patient_id
          end
        end

        def process_treatment_drug_classification(patient, period)
          key = :treatment_drug_classification

          return unless patient['date_diagonised'].present?

          patient_id = patient['patient_id']
          drugs = patient['drugs']&.split(',')&.map(&:downcase) || []

          drug_category_mapping.each do |category, drugs_list|
            next if report[key][category][period].include?(patient_id)

            report[key][category][period] << patient_id if drugs_list.any? { |drug| drugs.include?(drug) }
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
            diuretics: %w[htcz frusemide spironolactone bendrofluazide],
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
            SELECT p.patient_id,
                DATE(vitals.encounter_datetime) AS date_screened,
                DATE(diagnosed.date_diagonised) AS date_diagonised,
                treatment.drugs,
                lts_visit.lts_visit_date,
                lts_visit.lts_systolic,
                lts_visit.lts_diastolic,
                tpo.moh_cum_outcome,
                tpo.moh_outcome_date
            FROM patient p
            INNER JOIN encounter vitals ON vitals.patient_id = p.patient_id
                AND vitals.voided = 0
                AND vitals.encounter_type = #{encounter_type('VITALS').id}
            INNER JOIN obs systolic ON systolic.encounter_id = vitals.encounter_id
                AND systolic.voided = 0
                AND systolic.concept_id = #{concept('Systolic blood pressure').id}
            INNER JOIN obs diastolic ON diastolic.encounter_id = vitals.encounter_id
                AND diastolic.voided = 0
                AND diastolic.concept_id = #{concept('Diastolic blood pressure').id}
            LEFT JOIN (
                SELECT p.patient_id, date_diagnosied.value_datetime AS date_diagonised
                FROM patient p
                INNER JOIN encounter e ON e.patient_id = p.patient_id
                    AND e.voided = 0
                    AND e.encounter_type = #{encounter_type('HIV CLINIC CONSULTATION').id}
                INNER JOIN obs date_diagnosied ON date_diagnosied.encounter_id = e.encounter_id
                    AND date_diagnosied.voided = 0
                    AND date_diagnosied.concept_id = #{concept('Hypertension diagnosis date').id}
            ) diagnosed ON diagnosed.patient_id = p.patient_id
            LEFT JOIN (
                SELECT e.patient_id,#{' '}
                    encounter_datetime,
                    GROUP_CONCAT(DISTINCT c.name) AS drugs
                FROM encounter e
                INNER JOIN orders o ON o.encounter_id = e.encounter_id
                INNER JOIN concept_name c ON c.concept_id = o.concept_id
                WHERE e.voided = 0
                    AND e.encounter_type = #{encounter_type('TREATMENT').id}
                    AND o.voided = 0
                    AND e.program_id = #{program('HIV Program').id}
                AND DATE(e.encounter_datetime) > #{ActiveRecord::Base.connection.quote(start_date)}
                AND DATE(e.encounter_datetime) < #{ActiveRecord::Base.connection.quote(end_date)}
                GROUP BY patient_id
            ) treatment ON treatment.patient_id = p.patient_id
            AND DATE(treatment.encounter_datetime) >= diagnosed.date_diagonised
            LEFT JOIN (
                SELECT e.patient_id,
                        MAX(DATE(e.encounter_datetime)) AS lts_visit_date,
                        lts_systolic.value_numeric AS lts_systolic,
                        lts_diastolic.value_numeric AS lts_diastolic
                FROM encounter e
                    LEFT JOIN obs lts_systolic ON lts_systolic.encounter_id = e.encounter_id
                        AND lts_systolic.voided = 0
                        AND lts_systolic.concept_id = #{concept('Systolic blood pressure').id}
                    LEFT JOIN obs lts_diastolic ON lts_diastolic.encounter_id = e.encounter_id
                        AND lts_diastolic.voided = 0
                        AND lts_diastolic.concept_id = #{concept('Diastolic blood pressure').id}
                WHERE e.voided = 0
                AND e.encounter_type = #{encounter_type('VITALS').id}
                AND e.program_id = #{program('HIV Program').id}
                GROUP BY patient_id
            ) AS lts_visit ON lts_visit.patient_id = p.patient_id
             AND DATE(lts_visit.lts_visit_date) >= DATE(#{ActiveRecord::Base.connection.quote(start_date - 3.months)})
            LEFT JOIN temp_patient_outcomes tpo ON tpo.patient_id = p.patient_id
            WHERE vitals.program_id = #{program('HIV Program').id}
            AND DATE(vitals.encounter_datetime) <= #{ActiveRecord::Base.connection.quote(end_date)}
            GROUP BY patient_id
          SQL
        end
      end
    end
  end
end
