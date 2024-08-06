# frozen_string_literal: true

module ArtService
  module Reports
    module Ahd
      module AhdUtils
        def date_diff(start_date, end_date)
          (end_date.to_date - start_date.to_date).to_i
        end

        def patient_on_cpt?(patient)
          patient['started_cpt'] == 'Yes'
        end

        def patient_on_tpt?(patient)
          patient['started_tpt'] == 'Yes'
        end

        def serioully_ill?(_patient)
          false
        end

        def who_clinical_stage_done?(patient, *_kwargs)
          patient['who_stage']&.present?
        end

        def tested_for_cd4?(labs, *_kwargs)
          labs['CD4 count']&.present?
        end

        def who_stage_3_and_4_no_cd4?(patient, labs, *_kwargs)
          who_stage_criteria_met?(patient['who_stage']&.to_i) && !tested_for_cd4?(labs)
        end

        def cd4_less_than_200?(labs, *_kwargs)
          cd4_count_criteria_met?(labs['CD4 count'])
        end

        def auto_presenting_ahd?(patient, labs, *_kwargs)
          age_under_5?(patient['age']) || cd4_count_criteria_met?(labs['CD4 count'])
        end

        def new_hiv_pos_under_5?(patient, *_kwargs)
          age = patient['age']
          classification = patient['classification']

          classification == 'New Positive' && age_under_5?(age)
        end

        def new_hiv_pos_5_plus?(patient)
          age = patient['age']
          classification = patient['classification']

          classification == 'New Positive' && !age_under_5?(age)
        end

        def patient_meets_criteria?(patient, labs, rtt)
          who_stage = patient['who_stage']&.to_i
          patient_id = patient['patient_id']

          age_under_5?(patient['age']) ||
            who_stage_criteria_met?(who_stage) ||
            cd4_count_criteria_met?(labs['CD4 count']) ||
            hiv_viral_load_criteria_met?(labs['HIV Viral load']) ||
            is_rtt_patient?(patient_id, rtt)
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

        def who_stage_criteria_met?(who_stage)
          who_stage.in?(who_stage_3_and_4_ids)
        end

        def cd4_count_criteria_met?(cd4_count)
          return false unless cd4_count

          measure, result = cd4_count.split(',')
          measure == '<' && result.to_f <= 200
        end

        def hiv_viral_load_criteria_met?(hiv_viral_load)
          return false unless hiv_viral_load

          measure, result = hiv_viral_load.split(',')
          result.to_f > 1000 || (measure == '=' && result == 'LDL')
        end

        def patient_labs(results)
          Hash[JSON.parse("[#{results}]").flat_map(&:to_a)]
        end

        def find_rtt
          ArtService::Reports::ClinicTxRtt\
            .new(start_date: start_date.to_date, end_date: end_date.to_date)\
            .find_rtt_patients
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
