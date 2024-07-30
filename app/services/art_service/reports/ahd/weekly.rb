# frozen_string_literal: true

module ArtService
  module Reports
    module Ahd
      require 'ostruct'
      class Weekly
        attr_reader :start_date, :end_date, :report

        def initialize(start_date:, end_date:, **_kwargs)
          @start_date = ActiveRecord::Base.connection.quote(start_date)
          @end_date = ActiveRecord::Base.connection.quote(end_date)
          @report = OpenStruct.new
        end

        def find_report
          report.total_eligible = []
          report.total_high_viral_load = []
          report.total_first_time = []
          report.total_cd4_done = []
          report.total_cd4_greater_than_200 = []
          report.total_cd4_less_than_200 = []
          report.total_serum_crag_pos = []
          report.total_serum_crag_neg = []
          report.total_urine_lam_pos = []
          report.total_urine_lam_neg = []
          report.deaths = []
          report.transfered_out = []
          report.itt = []
          report.guardian_visits = []
          report.ma = []
          map_results

          report
        end

        def map_results
          stage_3 = ['WHO stage 3', 'WHO stage III adult', 'WHO stage III peds',
                     'WHO stage III criteria present', 'WHO stage III adult and peds']

          stage_4 = ['WHO stage 4', 'WHO stage IV adult', 'WHO stage IV peds',
                     'WHO stage IV criteria present', 'WHO stage IV adult and peds']

          who_stages = [stage_3 + stage_4].map { |x| x.map { |y| concept(y).concept_id } }.flatten

          query = builder.ahd_lab_orders
                         .merge(builder.who_stage)
                         .merge(builder.ahd_classification)
                         .merge(builder.ahd_outcomes)
                         .merge(builder.missed_appointments(start_date, end_date))
                         .merge(builder.guardian_visits(start_date, end_date))

          data = run(query)

          data.each do |row|
            results = row['test_results']
            labs = Hash[JSON.parse("[#{results}]").flat_map(&:to_a)]
            patient_id = row['patient_id']
            outcome = row['outcome']
            who_stage = row['who_stage']&.to_i

            report.total_eligible << patient_id if row['age']&.to_i&.< 5

            report.total_eligible << patient_id if who_stages.include?(who_stage)

            if labs.keys.include?('CD4 count')
              report.total_cd4_done << patient_id
              measure, result = labs['CD4 count'].split(',')
              if measure == '<' && result.to_f <= 200
                report.total_eligible << patient_id
                report.total_cd4_less_than_200 << patient_id
              elsif measure == '>' && result.to_f >= 200
                report.total_cd4_greater_than_200 << patient_id
              end
            end

            if labs.keys.include?('HIV Viral load')
              measure, result = labs['HIV Viral load'].split(',')
              if result.to_f > 1000 || (measure == '=' && result == 'LDL')
                report.total_eligible << patient_id
                report.total_high_viral_load << patient_id
              end
            end

            if labs.keys.include?('Serum CraG')
              _, result = labs['Serum CraG'].split(',')
              report.total_serum_crag_pos << patient_id if result == 'Positive'
              report.total_serum_crag_neg << patient_id if result == 'Negative'
            end

            if labs.keys.include?('Urine LAM')
              _, result = labs['Urine LAM'].split(',')
              report.total_urine_lam_pos << patient_id if result == 'Positive'
              report.total_urine_lam_neg << patient_id if result == 'Negative'
            end

            report.total_first_time << patient_id if row['classification'] == 'New Positive'

            report.deaths << patient_id if outcome == 'Died'
            report.transfered_out << patient_id if outcome == 'Transfer Out'

            report.ma << patient_id if row['missed_appointment'] == 'Yes'
            report.guardian_visits << patient_id if row['guardian_visit'] == 'Yes'

            report.total_eligible = report.total_eligible.uniq

            # TODO: Add ITT
          end
        end

        def run(sql)
          query = ActiveRecord::Base.connection.select_all(sql.to_sql)
          query.rows.map { |row| query.columns.zip(row).to_h }
        end

        def builder
          ArtService::Reports::Ahd::RegisterBuilder.new(start_date:, end_date:).register
        end
      end
    end
  end
end
