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
          @struct = %w[index label value]
          @num = 0
        end

        def map_orders(orders)
          orders.map do |order|
            order['test_results'] = Hash[JSON.parse("[#{order['test_results']}]").flat_map(&:to_a)]
            order
          end
        end

        def find_report
          symptoms = run(builder.ahd_symptoms)
          who_stages = run(builder.who_stage)
          orders = map_orders(run(builder.ahd_lab_orders))

          report.sex = build_genders
          report.age = build_age
          report.hiv_status = build_hiv_status
          report.last_taken_arvs = build_last_taken_arvs
          report.symptom_screening = build_symptom_screening(symptoms)
          report.who_stage = build_who_stage(who_stages)
          report.criteria_met = build_criteria_met(orders, who_stages)
          report.cd4_results = build_cd4_results(orders)
          report.hiv_viral_load = build_hiv_viral_load(orders)
          report.crag = build_crag(orders)
          report.csf_crag = build_csf_crag(orders)
          report.urine_lam = build_urine_lam(orders)
          report.genexpert = build_genexpert(orders)
          report.chest_xray = build_chest_xray(orders)
          report.fash = build_fash(orders)
          report.treatment_given = build_treatment_given
          report.seriously_ill = build_seriously_ill
          report.outcome = build_outcomes
          report.table
        end

        private

        def build_criteria_met(patients, who_stages)
          data = build_indicators(%w[yes no total missing])
          who_stage_ids = who_stage_3_and_4_ids

          patients.each do |patient|
            patient_id = patient['patient_id']
            labs = patient['test_results']
            who_stage = who_stages.find { |row| row['patient_id'] == patient_id }['who_stage']&.to_i

            data['yes'] << patient_id if patient_meets_criteria?(patient, who_stage_ids, labs, who_stage)
            data['no'] << patient_id unless data['yes'].include?(patient_id)
          end

          push_to_report('Criteria Met', data.keys, data)
        end

        def build_seriously_ill
          # TODO: make calculations for this
          data = build_indicators(%w[male fp])
          push_to_report('Seriously ill', data.keys, data)
        end

        def build_treatment_given
          # TODO: make calculations for this
          data = build_indicators(%w[tb meningitis cryptococcemia ks other missing])
          push_to_report('Treatnent given', data.keys, data)
        end

        def build_outcomes
          data = build_indicators(%w[discharged transfered_out ltfu died missing total])
          values = run(builder.ahd_outcomes)

          values.each do |row|
            outcome = row['outcome']&.downcase
            patient_id = row['patient_id']

            case outcome
            when 'discharged'
              data['discharged'] << patient_id
            when 'transfered out'
              data['transfered_out'] << patient_id
            when 'lost to follow up'
              data['ltfu'] << patient_id
            when 'died'
              data['died'] << patient_id
            end

            data['total'] = data['discharged'] + data['transfered_out'] + data['ltfu'] + data['died']
          end

          push_to_report('Outcome', data.keys, data)
        end

        def build_chest_xray(orders)
          build_test_results_report(orders, 'Chest X-ray', %w[abnormal normal missing total], 'Chest x-ray')
        end

        def build_fash(orders)
          build_test_results_report(orders, 'FASH', %w[abnormal normal missing total], 'FASH')
        end

        def build_genexpert(orders)
          build_test_results_report(orders, 'GeneXpert', %w[positive negative missing total], 'GeneXpert')
        end

        def build_urine_lam(orders)
          build_test_results_report(orders, 'Urine LAM', %w[positive negative missing total], 'Urine LAM')
        end

        def build_csf_crag(orders)
          build_test_results_report(orders, 'CSF crAg', %w[positive negative missing total], 'CSF crAg')
        end

        def build_crag(orders)
          build_test_results_report(orders, 'crAg', %w[positive negative missing total], 'crAg')
        end

        def build_hiv_viral_load(orders)
          build_test_results_report(orders, 'HIV Viral load', %w[<1000 1000+ missing total],
                                    'HIV Viral load') do |modifier, value|
            if modifier == '<' && value.to_i <= 1000
              '<1000'
            elsif modifier == '>' && value.to_i >= 1000
              '1000+'
            else
              'missing'
            end
          end
        end

        def build_cd4_results(orders)
          build_test_results_report(orders, 'CD4 count', %w[<200 1000+ not_done missing total],
                                    'CD4 Count') do |modifier, value|
            if modifier == '<' && value.to_i <= 200
              '<200'
            elsif modifier == '>' && value.to_i >= 1000
              '1000+'
            else
              'not_done'
            end
          end
        end

        def build_who_stage(who_stages)
          data = build_indicators(%w[who_1 who_2 who_3 who_4])
          values = who_stages

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

          values.each_key do |row|
            who_stage = row['who_stage']&.to_i

            data['who_1'] << row['patient_id'] if ConceptName.where(name: stage_1)
                                                             .pluck('concept_id')
                                                             .include?(who_stage)
            data['who_2'] << row['patient_id'] if ConceptName.where(name: stage_2)
                                                             .pluck('concept_id')
                                                             .include?(who_stage)
            data['who_3'] << row['patient_id'] if ConceptName.where(name: stage_3)
                                                             .pluck('concept_id')
                                                             .include?(who_stage)
            data['who_4'] << row['patient_id'] if ConceptName.where(name: stage_4)
                                                             .pluck('concept_id')
                                                             .include?(who_stage)
          end

          push_to_report('WHO Stage', data.keys, data)
        end

        def build_symptom_screening(s)
          data = build_indicators(%w[cough thrive fever mouth_sores shortness_of_breath cns yellow_eyes vomiting
                                     diarrhea neuropathy trunk missing])
          values = s

          values.each_key do |row|
            symptoms = row['symptoms'].split(',')

            data['cough'] << row['patient_id'] if symptoms.include?('Cough')
            data['thrive'] << row['patient_id'] if symptoms.include?('Thrive')
            data['fever'] << row['patient_id'] if symptoms.include?('Fever or Night sweats')
            data['mouth_sores'] << row['patient_id'] if symptoms.include?('Mouth sores')
            data['shortness_of_breath'] << row['patient_id'] if symptoms.include?('Shortness of breath')
            data['cns'] << row['patient_id'] if symptoms.include?('Central nervous system')
            data['yellow_eyes'] << row['patient_id'] if symptoms.include?('Yellow eyes')
            data['vomiting'] << row['patient_id'] if symptoms.include?('Vomiting/Abdominal pain')
            data['diarrhea'] << row['patient_id'] if symptoms.include?('Diarrhea')
            data['trunk'] << row['patient_id'] if symptoms.include?('Trunk')
            data['neropathy'] << row['patient_id'] if symptoms.include?('Peripheral Neropathy')
          end

          push_to_report('Symptom Screening', data.keys, data)
        end

        def build_last_taken_arvs
          data = build_indicators(%w[male fp fbf current])
          values = run(builder.ever_received_arvs)
          yes = concept('Yes').concept_id.to_s
          no = concept('No').concept_id.to_s

          values.each_key do |row|
            data['male'] << row['patient_id'] if row['arv'] == yes && row['gender'] == 'M'
            data['fp'] << row['patient_id'] if row['arv'] == yes && row['preg'] == yes
            data['fbf'] << row['patient_id'] if row['arv'] == yes && row['bf'] == yes
            data['current'] << row['patient_id'] if row['arv'] == no && row['current'].present?
          end

          push_to_report('Last Taken ARVs', data.keys, data)
        end

        def build_hiv_status
          new = 'New Positive'
          prev = 'Previous Positive'

          data = build_indicators(%w[new_positive prev_positive missing])
          values = run(builder.ahd_classification)

          values.each_key do |row|
            data['new_positive'] << row['patient_id'] if row['classification'] == new
            data['prev_positive'] << row['patient_id'] if row['classification'] == prev
            data['missing'] << row['patient_id'] if row['classification'] == 'Unknown'
          end

          push_to_report('HIV Status', data.keys, data)
        end

        def build_age
          data = build_indicators(%w[male fp fbf])
          values = run(builder.genders)

          values.each_key do |row|
            data['male'] << row['patient_id'] if row['gender'] == 'M'
            data['fp'] << row['patient_id'] if row['preg'] == 'Yes'
            data['fbf'] << row['patient_id'] if row['bf'] == 'Yes'
          end

          push_to_report('Age', data.keys, data)
        end

        def build_genders
          data = build_indicators(%w[male fp fbf fnp total])
          values = run(builder.genders)

          values.each_key do |row|
            data['total'] << row['patient_id']
            data['male'] << row['patient_id'] if row['gender'] == 'M'
            data['fp'] << row['patient_id'] if row['preg'] == 'Yes'
            data['fbf'] << row['patient_id'] if row['bf'] == 'Yes'
            data['fnp'] << row['patient_id'] if row['gender'] == 'F' && \
                                                [row['preg'], row['bf']].all? { |x| x == 'No' }
          end

          push_to_report('Sex', data.keys, data)
        end

        def push_to_report(caption, indicators, data)
          hash = OpenStruct.new
          hash.caption = caption
          hash.indicators = indicators.each_with_object({}) do |key, hash|
            hash[key] = value(data[key], key)
          end
          hash.table
        end

        def value(value, key)
          OpenStruct.new(
            index: @num.tap { @num += 1 },
            name: key,
            value: value || []
          ).table
        end

        def build_indicators(indicators)
          indicators.each_with_object({}) do |key, hash|
            hash[key] = []
          end
        end

        def run(sql)
          query = ActiveRecord::Base.connection.select_all(sql.to_sql)
          columns = query.columns
          rows = query.rows
          rows.map { |row| columns.zip(row).to_h }
        end

        def builder
          ArtService::Reports::Ahd::RegisterBuilder.new(start_date:, end_date:).register
        end
      end
    end
  end
end
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
          @struct = %w[index label value]
          @num = 0
        end

        def find_report
          report.sex = build_genders
          report.age = build_age
          report.hiv_status = build_hiv_status
          report.last_taken_arvs = build_last_taken_arvs
          symptoms = run(builder.ahd_symptoms)
          report.symptom_screening = build_symptom_screening(symptoms)
          report.criteria_met = build_criteria_met(symptoms)
          report.who_stage = build_who_stage
          orders = run(builder.ahd_lab_orders)
          report.cd4_results = build_cd4_results(orders)
          report.hiv_viral_load = build_hiv_viral_load(orders)
          report.crag = build_crag(orders)
          report.csf_crag = build_csf_crag(orders)
          report.urine_lam = build_urine_lam(orders)
          report.genexpert = build_genexpert(orders)
          report.chest_xray = build_chest_xray(orders)
          report.fash = build_fash(orders)
          report.outcome = build_outcomes
          report.table
        end

        private

        def build_criteria_met(symptoms)
          data = build_indicators(%w[yes no total missing])

          symptoms.each do |row|
            p_symptoms = row['symptoms'].split(',')
            data['total'] << row['patient_id']
            data['missing'] << row['patient_id'] if symptoms.empty?
            data['yes'] << row['patient_id'] if p_symptoms.count >= 2
            data['no'] << row['patient_id'] if p_symptoms.count < 2
          end

          push_to_report('Criteria Met', data.keys, data)
        end

        def build_outcomes
          data = build_indicators(%w[discharged transfered_out ltfu died missing total])
          values = run(builder.ahd_outcomes)

          values.each do |row|
            data['total'] << row['patient_id']
            data['discharged'] << row['patient_id'] if row['outcome'] == 'Discharged'
            data['transfered_out'] << row['patient_id'] if row['outcome'] == 'Transfered out'
            data['ltfu'] << row['patient_id'] if row['outcome'] == 'Lost to follow up'
            data['died'] << row['patient_id'] if row['outcome'] == 'Died'
          end

          push_to_report('Outcome', data.keys, data)
        end

        def build_chest_xray(orders)
          data = build_indicators(%w[abnormal normal missing total])
          crag = orders.filter { |o| o['name'] == 'Chest x-ray' }
          crag.each do |row|
            _, value = row['test_results'].split(',')
            data['total'] << row['patient_id']
            if value == 'Normal'
              data['normal'] << row['patient_id']
            elsif value == 'Abnormal'
              data['abnormal'] << row['patient_id']
            else
              data['missing'] << row['patient_id']
            end
          end

          push_to_report('Chest x-ray', data.keys, data)
        end

        def build_fash(orders)
          data = build_indicators(%w[abnormal normal missing total])
          crag = orders.filter { |o| o['name'] == 'FASH' }
          crag.each do |row|
            _, value = row['test_results'].split(',')
            data['total'] << row['patient_id']
            if value == 'Normal'
              data['normal'] << row['patient_id']
            elsif value == 'Abnormal'
              data['abnormal'] << row['patient_id']
            else
              data['missing'] << row['patient_id']
            end
          end
          push_to_report('Chest x-ray', data.keys, data)
        end

        def build_genexpert(orders)
          data = build_indicators(%w[positive negative missing total])
          crag = orders.filter { |o| o['name'] == 'GeneXpert' }
          crag.each do |row|
            _, value = row['test_results'].split(',')
            data['total'] << row['patient_id']
            if value == 'Positive'
              data['positive'] << row['patient_id']
            elsif value == 'Negative'
              data['negative'] << row['patient_id']
            else
              data['missing'] << row['patient_id']
            end
          end
          push_to_report('Chest x-ray', data.keys, data)
        end

        def build_urine_lam(orders)
          data = build_indicators(%w[positive negative missing total])
          crag = orders.filter { |o| o['name'] == 'Urine LAM' }
          crag.each do |row|
            _, value = row['test_results'].split(',')
            data['total'] << row['patient_id']
            if value == 'Positive'
              data['positive'] << row['patient_id']
            elsif value == 'Negative'
              data['negative'] << row['patient_id']
            else
              data['missing'] << row['patient_id']
            end
          end
          push_to_report('Chest x-ray', data.keys, data)
        end

        def build_csf_crag(orders)
          data = build_indicators(%w[positive negative missing total])
          crag = orders.filter { |o| o['name'] == 'CSF CrAg' }
          crag.each do |row|
            _, value = row['test_results'].split(',')
            data['total'] << row['patient_id']
            if value == 'Positive'
              data['positive'] << row['patient_id']
            elsif value == 'Negative'
              data['negative'] << row['patient_id']
            else
              data['missing'] << row['patient_id']
            end
          end
          push_to_report('Chest x-ray', data.keys, data)
        end

        def build_crag(orders)
          data = build_indicators(%w[positive negative missing total])
          crag = orders.filter { |o| o['name'] == 'CrAg' }
          crag.each do |row|
            _, value = row['test_results'].split(',')
            data['total'] << row['patient_id']
            if value == 'Positive'
              data['positive'] << row['patient_id']
            elsif value == 'Negative'
              data['negative'] << row['patient_id']
            else
              data['missing'] << row['patient_id']
            end
          end
          push_to_report('Chest x-ray', data.keys, data)
        end

        def build_hiv_viral_load(orders)
          data = build_indicators(%w[<1000 1000+ missing total])
          vl = orders.filter { |o| o['name'] == 'HIV Viral load' }

          vl.each do |row|
            data['total'] << row['patient_id']
            modifier, value = row['test_results'].split(',')
            if modifier == '<' && value.to_i <= 1000
              data['<1000'] << row['patient_id']
            elsif modifier == '>' && value.to_i >= 1000
              data['1000+'] << row['patient_id']
            else
              data['missing'] << row['patient_id']
            end
          end
          push_to_report('Chest x-ray', data.keys, data)
        end

        def build_cd4_results(orders)
          data = build_indicators(%w[<200 1000+ not_done missing total])
          cd4_tests = orders.filter { |o| o['name'] == 'CD4 count' }
          cd4_tests.each do |row|
            data['total'] << row['patient_id']
            modifier, value = row['test_results'].split(',')
            if modifier == '<' && value.to_i <= 200
              data['<200'] << row['patient_id']
            elsif modifier == '>' && value.to_i >= 1000
              data['1000+'] << row['patient_id']
            else
              data['not_done'] << row['patient_id']
            end
          end

          push_to_report('CD4 Count', data.keys, data)
        end

        def build_who_stage
          data = build_indicators(%w[who_1 who_2 who_3 who_4])
          values = run(builder.who_stage)

          stage_1 = ['WHO stage 1', 'WHO stage I',
                     'WHO stage I adult', 'WHO stage I peds',
                     'WHO stage I criteria present',
                     'WHO stage I adult and peds']

          stage_2 = ['WHO stage 2', 'WHO stage II',
                     'WHO stage II adult', 'WHO stage II peds',
                     'WHO stage II criteria present',
                     'WHO stage II adult and peds']

          stage_3 = ['WHO stage 3', 'WHO stage III',
                     'WHO stage III adult', 'WHO stage III peds',
                     'WHO stage III criteria present',
                     'WHO stage III adult and peds']

          stage_4 = ['WHO stage 4', 'WHO stage IV',
                     'WHO stage IV adult', 'WHO stage IV peds',
                     'WHO stage IV criteria present',
                     'WHO stage IV adult and peds']

          values.each do |row|
            who_stage = row['who_stage']&.to_i
            patient_id = row['patient_id']

            stage_groups.each do |key, stages|
              data[key] << patient_id if ConceptName.where(name: stages).pluck('concept_id').include?(who_stage)
            end
          end

          push_to_report('WHO Stage', data.keys, data)
        end

        def build_symptom_screening(values)
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
            'missing' => ''
          }
          data = build_indicators(symptom_map.keys)
          values.each do |row|
            symptoms = row['symptoms'].split(',')
            patient_id = row['patient_id']

            symptom_map.each do |key, symptom|
              data[key] << patient_id if symptoms.include?(symptom)
            end
          end

          push_to_report('Symptom Screening', data.keys, data)
        end

        def build_last_taken_arvs
          data = build_indicators(%w[male fp fbf current])
          values = run(builder.ever_received_arvs)
          yes = concept('Yes').concept_id.to_s
          no = concept('No').concept_id.to_s

          values.each do |row|
            patient_id = row['patient_id']

            data['male'] << patient_id if row['arv'] == yes && row['gender'] == 'M'
            data['fp'] << patient_id if row['arv'] == yes && row['preg'] == yes
            data['fbf'] << patient_id if row['arv'] == yes && row['bf'] == yes
            data['current'] << patient_id if row['arv'] == no && row['current'].present?
          end

          push_to_report('Last Taken ARVs', data.keys, data)
        end

        def build_hiv_status
          new = 'New Positive'
          prev = 'Previous Positive'

          data = build_indicators(%w[new_positive prev_positive missing])
          values = run(builder.ahd_classification)

          values.each do |row|
            patient_id = row['patient_id']
            data['new_positive'] << patient_id if row['classification'] == new
            data['prev_positive'] << patient_id if row['classification'] == prev
            data['missing'] << patient_id if row['classification'] == 'Unknown'
          end

          push_to_report('HIV Status', data.keys, data)
        end

        def build_age
          data = build_indicators(%w[male fp fbf])
          values = run(builder.genders)

          values.each do |row|
            patient_id = row['patient_id']
            data['male'] << patient_id if row['gender'] == 'M'
            data['fp'] << patient_id if row['preg'] == 'Yes'
            data['fbf'] << patient_id if row['bf'] == 'Yes'
          end

          push_to_report('Age', data.keys, data)
        end

        def build_genders
          data = build_indicators(%w[male fp fbf fnp total])
          values = run(builder.genders)

          values.each do |row|
            patient_id = row['patient_id']

            data['total'] << patient_id
            data['male'] << patient_id if row['gender'] == 'M'
            data['fp'] << patient_id if row['preg'] == 'Yes'
            data['fbf'] << patient_id if row['bf'] == 'Yes'
            data['fnp'] << patient_id if row['gender'] == 'F' &&
                                         [row['preg'], row['bf']].all? { |x| x == 'No' }
          end

          push_to_report('Sex', data.keys, data)
        end

        def build_stage_report(values, stage_groups, report_title)
          data = initialize_data(stage_groups.keys)
          values.each do |row|
            who_stage = row['who_stage']&.to_i
            stage_groups.each do |key, stages|
              data[key] << row['patient_id'] if ConceptName.where(name: stages).pluck('concept_id').include?(who_stage)
            end
          end
          push_to_report(report_title, data.keys, data)
        end

        def build_symptom_report(values, symptom_map, report_title)
          data = initialize_data(symptom_map.keys)
          values.each do |row|
            symptoms = row['symptoms'].split(',')
            patient_id = row['patient_id']
            symptom_map.each do |key, symptom|
              data[key] << patient_id if symptoms.include?(symptom)
            end
          end
          push_to_report(report_title, data.keys, data)
        end

        def build_test_results_report(orders, test_name, indicators, report_title)
          data = build_indicators(indicators)

          orders.each do |row|
            labs = row['test_results']
            patient_id = row['patient_id']

            next unless labs.keys.include?(test_name)

            data['total'] << patient_id
            modifier, value = labs[test_name].split(',')

            result = if block_given?
                       yield(modifier, value)
                     else
                       value.downcase
                     end

            data[result] << patient_id if data.keys.include?(result)
          end

          push_to_report(report_title, data.keys, data)
        end

        def patient_meets_criteria?(patient, who_stage_ids, labs, who_stage)
          age_under_5?(patient['age']) ||
            who_stage_criteria_met?(who_stage_ids, who_stage) ||
            cd4_count_criteria_met?(labs['CD4 count']) ||
            hiv_viral_load_criteria_met?(labs['HIV Viral load'])
        end

        def who_stage_3_and_4_ids
          stage_3 = ['WHO stage 3', 'WHO stage III adult', 'WHO stage III peds',
                     'WHO stage III criteria present', 'WHO stage III adult and peds']

          stage_4 = ['WHO stage 4', 'WHO stage IV adult', 'WHO stage IV peds',
                     'WHO stage IV criteria present', 'WHO stage IV adult and peds']

          [stage_3 + stage_4].flatten.map { |x| concept(x).concept_id }
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

        def push_to_report(caption, indicators, data)
          hash = OpenStruct.new
          hash.caption = caption
          hash.indicators = indicators.each_with_object({}) do |key, hash|
            hash[key] = value(data[key], key)
          end
          hash.table
        end

        def value(value, key)
          OpenStruct.new(
            index: @num.tap { @num += 1 },
            name: key,
            value: value || []
          ).table
        end

        def build_indicators(indicators)
          indicators.each_with_object({}) do |key, hash|
            hash[key] = []
          end
        end

        def run(sql)
          query = ActiveRecord::Base.connection.select_all(sql.to_sql)
          columns = query.columns
          rows = query.rows
          rows.map { |row| columns.zip(row).to_h }
        end

        def builder
          ArtService::Reports::Ahd::RegisterBuilder.new(start_date:, end_date:).register
        end
      end
    end
  end
end
