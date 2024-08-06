# frozen_string_literal: true

module ArtService
  module Reports
    module Ahd
      require 'ostruct'
      class MonthlyDisaggregated
        include Reports::Pepfar::Utils
        include AhdUtils

        attr_reader :start_date, :end_date, :report

        def initialize(start_date:, end_date:, **_kwargs)
          @start_date = ActiveRecord::Base.connection.quote(start_date)
          @end_date = ActiveRecord::Base.connection.quote(end_date)
          @report = {}
          @num = 0
        end

        def find_report
          rtt_patients = find_rtt
          queries = [
            builder.genders,
            builder.who_stage,
            builder.age_group(end_date),
            builder.ahd_lab_orders(start_date, end_date),
            builder.ahd_classification,
            builder.started_cpt,
            builder.started_tpt,
            builder.ahd_outcomes(end_date),
            builder.outcome_date(start_date)
          ]

          patients = builder.run(queries.reduce(&:merge))

          patients.each do |row|
            map_screening_data(row, rtt_patients)
            map_diagnosis_data(row)
            map_tb_screening(row)
            map_on_cpt_and_tpt(row)
            map_ahd_outcomes(row)
          end
          map_treatment_data(patients)

          report
        end

        private

        def map_ahd_outcomes(patient)
          indicators = %w[current_in_care outcome_at_six_months outcome_at_twelve_months]
          categories = %w[alive_and_in_treatment patient_died defaulted treatment_stopped patient_transfered_out]
          indicators.each { |i| add_report_keys(i, categories) }

          outcome = patient['outcome']&.camelcase&.downcase
          outcome_date = patient['outcome_date']

          to_report(patient, 'current_in_care', outcome) if date_diff(outcome_date, end_date) < 180
          to_report(patient, 'outcome_at_six_months', outcome) if date_diff(outcome_date,
                                                                            end_date) >= 180 && date_diff(outcome_date,
                                                                                                          end_date) < 360
          to_report(patient, 'outcome_at_twelve_months', outcome) if date_diff(outcome_date, end_date) >= 360
        end

        def map_treatment_data(patients)
          add_report_keys('on_tb_treatment', %w[total])
          ids = patients.map { |p| p['patient_id'] }
          builder.patients_on_tb_treatment(ids).each do |result|
            patient = patients.find { |p| p['patient_id'] == result.first }
            to_report(patient, 'on_tb_treatment')
          end
        end

        def map_on_cpt_and_tpt(patient)
          add_report_keys('started_cpt', %w[total])
          add_report_keys('started_tpt', %w[total])

          to_report(patient, 'started_cpt') if patient_on_cpt?(patient)
          to_report(patient, 'started_tpt') if patient_on_tpt?(patient)
        end

        def map_tb_screening(patient)
          tb_tests_map = {
            urine_lam: ['Urine LAM'],
            genexpert: ['GeneXpert'],
            urine_lam_and_genexpert: ['Urine LAM', 'GeneXpert'],
            fash: ['FASH'],
            xray: ['TB Microscopic Exam']
          }
          indicators = %w[tested_tb tested_tb_positive]
          indicators.each { |i| add_report_keys(i, tb_tests_map.keys) }

          labs = patient_labs(patient['test_results'])

          available_tests = labs.keys

          tb_tests_map.each do |key, values|
            next unless values.all? { |v| available_tests.include?(v) }

            to_report(patient, 'tested_tb', key.to_s)

            tests = labs.select { |k, _v| values.include?(k) }

            to_report(patient, 'tested_tb_positive', key.to_s)\
              if tests.all? { |_, result| result.split(',').last == 'Positive' }
          end

          # TODO: calculate for TB clinical assessment
        end

        def add_report_keys(indicator, categories)
          report[indicator.to_s] ||= {}
          categories.each do |c|
            report[indicator.to_s][c.to_s] ||= \
              %w[M F].each_with_object({}) do |gender, g|
                g[gender] = pepfar_age_groups.each_with_object({}) do |group, g|
                  g[group] = []
                end
              end
          end
        end

        def map_diagnosis_data(patient)
          labs = patient_labs(patient['test_results'])

          indicators = %w[serum_crag positive_serum_crag csf_crag positive_csf_crag prophylaxis
                          started_prophylaxis_treatment]
          indicators.each { |i| add_report_keys(i, %w[total]) }

          if labs['CSF crAg'].present?
            to_report(patient, 'csf_crag')
            to_report(patient, 'positive_csf_crag')\
             if positive_for_serum_crag?(labs['CSF crAg'])
          end

          return unless labs['Serum crAg'].present?

          to_report(patient, 'serum_crag')
          to_report(patient, 'positive_serum_crag')\
           if positive_for_serum_crag?(labs['Serum crAg'])
        end

        def to_report(patient, indicator, category = nil)
          patient_id = patient['patient_id']
          group = patient['age_group']
          gender = patient['gender']
          return report[indicator.to_s][category.to_s][gender][group] << patient_id if category.present?

          report[indicator]['total'][gender][group] << patient_id
        end

        def map_screening_data(row, rtt_patients)
          labs = patient_labs(row['test_results'])

          indicators = %w[
            eligible_for_ahd_screening who_clinical_stage_done tested_for_cd4
            who_stage_3_and_4_no_cd4 cd4_less_than_200 auto_presenting_ahd
          ]
          categories = %w[new_hiv_pos_five_plus new_hiv_pos_under_five high_viral_load rtt serioully_ill]

          indicators.each { |i| add_report_keys(i, categories) }
          patient_indicators = {
            'eligible_for_ahd_screening' => :patient_meets_criteria?,
            'who_clinical_stage_done' => :who_clinical_stage_done?,
            'tested_for_cd4' => :tested_for_cd4?,
            'who_stage_3_and_4_no_cd4' => :who_stage_3_and_4_no_cd4?,
            'cd4_less_than_200' => :cd4_less_than_200?,
            'auto_presenting_ahd' => :auto_presenting_ahd?
          }

          patient_indicators.each do |indicator, method|
            map_patient(indicator, row, labs, rtt_patients) if send(method, row, labs, rtt_patients)
          end
        end

        def map_patient(indicator, patient, labs, rtt_patients)
          patient_id = patient['patient_id']
          patient_conditions = {
            'new_hiv_pos_five_plus' => new_hiv_pos_5_plus?(patient),
            'new_hiv_pos_under_five' => new_hiv_pos_under_5?(patient),
            'high_viral_load' => hiv_viral_load_criteria_met?(labs['HIV Viral load']),
            'rtt' => is_rtt_patient?(patient_id, rtt_patients),
            'serioully_ill' => serioully_ill?(patient)
          }

          patient_conditions.each do |key, result|
            add_report_keys(indicator, [key])
            to_report(patient, indicator, key) if result
          end
        end
      end
    end
  end
end
