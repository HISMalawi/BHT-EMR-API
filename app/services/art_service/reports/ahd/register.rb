# frozen_string_literal: true

module ArtService
  module Reports
    module Ahd
      require 'ostruct'
      class Register
        attr_reader :start_date, :end_date, :report

        def initialize(start_date:, end_date:, **_kwargs)
          @start_date = ActiveRecord::Base.connection.quote(start_date)
          @end_date = ActiveRecord::Base.connection.quote(end_date)
          @report = OpenStruct.new
          @num = 0
        end
        
        def find_report

          rtt_patients = find_rtt

          queries = [
            builder.genders,
            builder.ahd_classification,
            builder.ever_received_arvs,
            builder.ahd_outcomes(end_date),
            builder.ahd_symptoms,
            builder.who_stage,
            builder.ahd_lab_orders(start_date, end_date)
          ]

          data = builder.run(queries.reduce(&:merge))

          data.each do |row|
            map_report_data(row, rtt_patients)
          end

          format_report
        end

        private

        def find_rtt
          ArtService::Reports::ClinicTxRtt\
            .new(start_date: start_date.to_date, end_date: end_date.to_date)\
            .find_rtt_patients
        end

        def format_report
          formated = {}
          report.table.each do |key, value|
            formated[key] = report_format(key.to_s.humanize, value.keys, value)
          end
          formated
        end

        def map_report_data(row, rtt_patients)
          labs = Hash[JSON.parse("[#{row['test_results']}]").flat_map(&:to_a)]
          patient_id = row['patient_id']
          outcome = row['outcome']
          who_stage = row['who_stage']&.to_i
          symptoms = row['symptoms']
          gender = row['gender']
          bf = row['bf']&.to_i
          preg = row['preg']&.to_i
          current = row['current']&.to_i
          classification = row['classification']&.to_i
          arvs = row['arvs']&.to_i

          build_age(patient_id, gender, preg, bf)
          build_genders(patient_id, gender, preg, bf)
          build_criteria_met(row, labs, rtt_patients)
          build_seriously_ill(patient_id)
          build_treatment_given(patient_id)
          build_outcomes(patient_id, outcome)
          build_all_test_reports(patient_id, labs)
          build_who_stage(patient_id, who_stage)
          build_symptom_screening(patient_id, symptoms)
          build_last_taken_arvs(patient_id, gender, arvs, preg, bf, current)
          build_hiv_classification(patient_id, classification)
        end

        def build_criteria_met(patient, labs, rtt_patients)
          indicator = 'criteria_met'
          build_indicators(indicator, %w[yes no missing])

          patient_id = patient['patient_id']

          report[indicator]['yes'] << patient_id\
           if patient_meets_criteria?(patient, labs, rtt_patients)

          report[indicator]['no'] << patient_id\
           unless report[indicator]['yes'].include?(patient_id)
        end

        def build_seriously_ill(patient_id)
          indicator = 'seriously_ill'
          # TODO: make calculations for this
          build_indicators(indicator, %w[male fp])
        end

        def build_treatment_given(patient_id)
          indicator = 'treatment_given'
          # TODO: make calculations for this
          build_indicators(indicator, %w[tb meningitis cryptococcemia ks other missing])
        end

        def build_outcomes(patient_id, outcome)
          indicator = 'treatment_given'
          build_indicators(indicator, %w[discharged transfered_out ltfu died missing])
          mapping = {
            'patient transferred out' => 'transfered_out',
            'patient died' => 'died',
            'defaulted' => 'ltfu',
            'discharged' => 'discharged'
          }
          report[indicator][mapping[outcome]] << patient_id if mapping[outcome]
        end

        def build_all_test_reports(patient_id, tests)
          map = [
            { indicator: 'chest_xray', name: 'Chest X-ray', result_types: %w[abnormal normal missing] },
            { indicator: 'fash', name: 'FASH', result_types: %w[abnormal normal missing] },
            { indicator: 'genexpert', name: 'GeneXpert', result_types: %w[positive negative missing] },
            { indicator: 'urine_lam', name: 'Urine LAM', result_types: %w[positive negative missing] },
            { indicator: 'csf_crag', name: 'CSF crAg', result_types: %w[positive negative missing] },
            { indicator: 'crag', name: 'crAg', result_types: %w[positive negative missing] }
          ]
          vl_indicators = %w[<1000 1000+ missing]
          cd4_indicators = %w[<200 1000+ not_done missing]
        

          map.each do |config|
            build_test_results_report(patient_id, tests, config[:name], config[:result_types], config[:indicator])
          end

          build_test_results_report(patient_id, tests, 'HIV Viral load', vl_indicators, 'hiv_viral_load') do |modifier, value|
            if modifier == '<' && value.to_i <= 1000
              '<1000'
            elsif modifier == '>' && value.to_i >= 1000
              '1000+'
            else
              'missing'
            end
          end

          build_test_results_report(patient_id, tests, 'CD4 count', cd4_indicators, 'cd4_count') do |modifier, value|
            if modifier == '<' && value.to_i <= 200
              '<200'
            elsif modifier == '>' && value.to_i >= 1000
              '1000+'
            else
              'not_done'
            end
          end
        end

        def build_who_stage(patient_id, who_stage)
          indicator = 'who_stage'
          build_indicators(indicator, %w[who_1 who_2 who_3 who_4])
          stage_groups = {
            'who_1' => ['WHO stage 1', 'WHO stage I', 'WHO stage I adult', 'WHO stage I peds',
                        'WHO stage I criteria present', 'WHO stage I adult and peds'],
            'who_2' => ['WHO stage 2', 'WHO stage II', 'WHO stage II adult', 'WHO stage II peds',
                        'WHO stage II criteria present', 'WHO stage II adult and peds'],
            'who_3' => ['WHO stage 3', 'WHO stage III', 'WHO stage III adult', 'WHO stage III peds',
                        'WHO stage III criteria present', 'WHO stage III adult and peds'],
            'who_4' => ['WHO stage 4', 'WHO stage IV', 'WHO stage IV adult', 'WHO stage IV peds',
                        'WHO stage IV criteria present', 'WHO stage IV adult and peds']
          }

          stage_groups.each do |key, stages|
            report[indicator][key] << patient_id if ConceptName.where(name: stages).pluck('concept_id').include?(who_stage)
          end
        end

        def build_symptom_screening(patient_id, symptoms)
          symptom_map = {
            'cough' => 'Cough',
            'thrive' => 'Thrive',
            'fever' => 'Fever or Night sweats',
            'mouth_sores' => 'Mouth sores',
            'shortness_of_breath' => 'Shortness of breath',
            'cns' => 'Central nervous system',
            'yellow_eyes' => 'Yellow eyes',
            'vomiting' => 'Vomiting/Abdominal pain',
            'diarrhea' => 'Diarrhea',
            'trunk' => 'Trunk',
            'neuropathy' => 'Peripheral Neuropathy',
            'missing' => 'Missing'
          }
          indicator = 'symptom_screening'
          build_indicators(indicator, symptom_map.keys)
          
          symptom_map.each do |key, symptom|
            report[indicator][key] << patient_id if symptom.in?(symptoms)
          end
        end

        def build_last_taken_arvs(patient_id, gender, arv, preg, bf, current)
          indicator = 'last_taken_arvs'
          build_indicators(indicator, %w[male fp fbf current])
          yes = concept('Yes').concept_id.to_s
          no = concept('No').concept_id.to_s

          report[indicator]['male'] << patient_id if arv == yes && gender == 'M'
          report[indicator]['fp'] << patient_id if arv == yes && preg == yes
          report[indicator]['fbf'] << patient_id if arv == yes && bf == yes
          report[indicator]['current'] << patient_id if arv == no && current.present?
        end

        def build_hiv_classification(patient_id, classification)
          indicator = 'hiv_classification'
          build_indicators(indicator, %w[new_positive prev_positive missing])
          new = 'New Positive'
          prev = 'Previous Positive'

          report[indicator]['new_positive'] << patient_id if classification == new
          report[indicator]['prev_positive'] << patient_id if classification == prev
          report[indicator]['missing'] << patient_id if classification == 'Unknown'
        end

        def build_age(patient_id, gender, preg, bf)
          indicator = 'age'
          build_indicators(indicator, %w[male fp fbf])
          yes = concept('Yes').concept_id          
          
          report[indicator]['male'] << patient_id if gender == 'M'
          report[indicator]['fbf'] << patient_id if bf == yes
          report[indicator]['fp'] << patient_id if preg == yes
        end

        def build_genders(patient_id, gender, preg, bf)
          indicator = 'gender'
          build_indicators(indicator, %w[male fp fbf fnp])
          yes = concept('Yes').concept_id
          
          report[indicator]['male'] << patient_id if gender == 'M'
          report[indicator]['fp'] << patient_id if preg == yes
          report[indicator]['fbf'] << patient_id if bf == yes
          report[indicator]['fnp'] << patient_id if gender == 'F' && [preg, bf].all? { |x| x == 'No' }
        end

        def build_test_results_report(patient_id, results, test_name, options, indicator)
          build_indicators(indicator, options)
          
          return unless results.keys.include?(test_name)
          
          test = results[test_name]
          modifier, value = test.split(',')

          result = block_given? ? yield(modifier, value) : value.downcase

          report[indicator][result] << patient_id
        end

        def patient_meets_criteria?(patient, labs, rtt_patients)
          who_stage = patient['who_stage']&.to_i
          patient_id = patient['patient_id']

          age_under_5?(patient['age']) ||
            who_stage_criteria_met?(who_stage_3_and_4_ids, who_stage) ||
            cd4_count_criteria_met?(labs['CD4 count']) ||
            hiv_viral_load_criteria_met?(labs['HIV Viral load']) ||
            is_rtt_patient?(patient_id, rtt_patients)
        end

        def who_stage_3_and_4_ids
          stage_3 = ['WHO stage 3', 'WHO stage III adult', 'WHO stage III peds',
                     'WHO stage III criteria present', 'WHO stage III adult and peds']

          stage_4 = ['WHO stage 4', 'WHO stage IV adult', 'WHO stage IV peds',
                     'WHO stage IV criteria present', 'WHO stage IV adult and peds']

          [stage_3 + stage_4].flatten.map { |x| concept(x).concept_id }
        end

        def is_rtt_patient?(patient_id, rtt_patients)
          rtt_patients.any? { |x| x['patient_id'] == patient_id }
        end

        def age_under_5?(age)
          age&.to_i&.< 5
        end

        def who_stage_criteria_met?(who_stage_ids, who_stage)
          who_stage_ids.include?(who_stage)
        end

        def cd4_count_criteria_met?(cd4_count)
          measure, result = cd4_count.split(',')
          measure == '<' && result.to_f <= 200
        end

        def hiv_viral_load_criteria_met?(hiv_viral_load)
          measure, result = hiv_viral_load.split(',')
          result.to_f > 1000 || (measure == '=' && result == 'LDL')
        end

        def report_format(caption, indicators, data)
          hash = OpenStruct.new
          hash.caption = caption
          hash.indicators = indicators.each_with_object({}) do |key, hash|
            hash[key] = value(data[key], key)
          end
          hash['indicators']['total'] = value(data.values.flatten.uniq, 'total')
          hash.table
        end

        def value(value, key)
          OpenStruct.new(
            index: @num.tap { @num += 1 },
            name: key,
            value: value || []
          ).table
        end

        def build_indicators(indicator, keys)
          report[indicator] ||= {}
          keys.each_with_object({}) do |key, hash|
            report[indicator][key] ||= []
          end
        end

        def builder
          ArtService::Reports::Ahd::RegisterBuilder\
            .new(start_date:, end_date:)\
            .register
        end
      end
    end
  end
end
