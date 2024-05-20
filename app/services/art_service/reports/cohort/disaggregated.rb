# frozen_string_literal: true

module ArtService
  module Reports
    module Cohort
      # Disaggregated cohort report
      # rubocop:disable Metrics/ClassLength
      class Disaggregated
        attr_accessor :type, :start_date, :end_date, :rebuild, :occupation, :report, :maternal

        include ModelUtils
        include ArtService::Reports::Pepfar::Utils

        def initialize(start_date:, end_date:, **kwargs)
          @type = kwargs[:type]
          @start_date = start_date
          @end_date = end_date
          @rebuild = kwargs[:rebuild]&.casecmp?('true')
          @occupation = kwargs[:occupation]
          @maternal = {}
        end

        def find_report
          rebuild_report if rebuild
          update_outcomes unless rebuild
          process_initialization
          process_data
          flatten_data
        end

        private

        GENDER = %w[M F].freeze
        AGGREGATE_GENDER_ROWS = %w[M FP FNP FBf].freeze

        def process_initialization
          init_report
          init_aggregate_rows
        end

        def init_report
          @report = pepfar_age_groups.each_with_object({}) do |age_group, report|
            report[age_group] = {}
            GENDER.each do |gender|
              report[age_group][gender] = {}
              init_cohort_section(report[age_group][gender])
            end
          end
        end

        def init_aggregate_rows
          report['All'] = {}
          AGGREGATE_GENDER_ROWS.each do |gender|
            report['All'][gender] = {}
            init_cohort_section(report['All'][gender])
          end
        end

        def init_cohort_section(cursor)
          COHORT_REGIMENS.each do |regimen|
            cursor[regimen] = []
          end
          cursor['unknown'] = []
          cursor['total'] = []
        end

        def process_data
          process_db_data
          process_maternal_data
        end

        # rubocop:disable Metrics/AbcSize
        def process_db_data
          fetch_data.each do |data|
            age_group = data['age_group']
            regimen = data['regimen']
            patient_id = data['patient_id']
            # we need to handle regimes that only have one P to become PP. Otherwise if it is already PP or PA we leave
            # it as is. Regimens are in this format NUMBERLETTERS
            regimen = regimen.gsub(/(\d+[A-Za-z]*P)\z/, '\1P') if regimen.match?(/\A\d+[A-Za-z]*[^P]P\z/)
            gender = data['gender']
            report[age_group.to_s][gender.to_s][regimen.to_s] << patient_id
            report[age_group.to_s][gender.to_s]['total'] << patient_id
            process_aggregate_rows(gender:, regimen:, patient_id:)
          end
        end

        def process_maternal_data
          result = ArtService::Reports::Pepfar::ViralLoadCoverage2.new(start_date:, end_date:, occupation:)
                                                                  .vl_maternal_status(maternal.keys)
          # result comes in this form: { FP: [], FBf: [] }
          # we need to loop through the keys
          result.each_key do |key|
            result[key].each do |patient_id|
              puts "Process patient: #{patient_id} on regimen: #{maternal[patient_id]}. Category: #{key}"
              report['All'][key.to_s][maternal[patient_id].to_s] << patient_id
              report['All'][key.to_s]['total'] << patient_id
            end
          end
        end
        # rubocop:enable Metrics/AbcSize

        def process_aggregate_rows(gender:, regimen:, patient_id:)
          if gender == 'M'
            report['All']['M'][regimen.to_s] << patient_id
            report['All']['M']['total'] << patient_id
          else
            maternal[patient_id] = regimen
          end
        end

        # we need to flatten the data
        def flatten_data
          flat_data = []
          report.each do |age_group, gender_data|
            gender_data.each do |gender, regimen_data|
              flat_data << {
                'age_group' => age_group,
                'gender' => gender,
                **regimen_data
              }
            end
          end
          flat_data
        end

        # rubocop:disable Metrics/MethodLength
        def fetch_data
          ActiveRecord::Base.connection.select_all <<~SQL
            SELECT
                prescriptions.patient_id,
                COALESCE(regimens.name, 'unknown') AS regimen,
                prescriptions.age_group,
                prescriptions.gender
            FROM (
                SELECT
                    tcm.patient_id,
                    GROUP_CONCAT(DISTINCT(tcm.drug_id) ORDER BY tcm.drug_id ASC) AS drugs,
                    disaggregated_age_group(date(earliest_start_date.birthdate), date('#{end_date}')) AS age_group,
                    earliest_start_date.gender
                FROM temp_current_medication tcm
                INNER JOIN temp_patient_outcomes AS outcomes ON outcomes.patient_id = tcm.patient_id AND outcomes.cum_outcome = 'On antiretrovirals'
                INNER JOIN temp_earliest_start_date AS earliest_start_date ON earliest_start_date.patient_id = tcm.patient_id
                GROUP BY tcm.patient_id
            ) AS prescriptions
            LEFT JOIN (
                SELECT GROUP_CONCAT(drug.drug_id ORDER BY drug.drug_id ASC) AS drugs, regimen_name.name AS name
                FROM moh_regimen_combination AS combo
                INNER JOIN moh_regimen_combination_drug AS drug USING (regimen_combination_id)
                INNER JOIN moh_regimen_name AS regimen_name USING (regimen_name_id)
                GROUP BY combo.regimen_combination_id
            ) AS regimens ON regimens.drugs = prescriptions.drugs
          SQL
        end
        # rubocop:enable Metrics/MethodLength

        def update_outcomes
          ArtService::Reports::Cohort::Outcomes.new(end_date:, occupation:,
                                                    definition: type).update_cummulative_outcomes
        end

        def rebuild_report
          ArtService::Reports::CohortBuilder.new(outcomes_definition: type)
                                            .init_temporary_tables(start_date, end_date, occupation)
        end
      end
      # rubocop:enable Metrics/ClassLength
    end
  end
end
