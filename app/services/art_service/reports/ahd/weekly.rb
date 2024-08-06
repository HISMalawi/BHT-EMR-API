# frozen_string_literal: true

module ArtService
  module Reports
    module Ahd
      require 'ostruct'
      class Weekly
        include AhdUtils
        attr_reader :start_date, :end_date, :report

        def initialize(start_date:, end_date:, **_kwargs)
          @start_date = ActiveRecord::Base.connection.quote(start_date)
          @end_date = ActiveRecord::Base.connection.quote(end_date)
          @report = OpenStruct.new
        end

        def find_report
          indicators = %w[
            total_eligible total_high_viral_load total_first_time
            total_back_to_care total_cd4_done total_cd4_greater_than_200
            total_cd4_less_than_200 total_serum_crag_pos total_serum_crag_neg
            total_urine_lam_pos total_urine_lam_neg deaths transfered_out guardian_visits ma
          ]

          indicators.each { |i| report.send("#{i}=", []) }

          map_results

          fmt_report
        end

        def fmt_report
          fmt = []
          report.table.each_key do |key|
            data = {}
            data['indicator'] = key.to_s.humanize
            data['count'] = report.table[key]
            fmt << data
          end
          fmt
        end

        def map_results
          queries = [
            builder.ahd_lab_orders(start_date, end_date),
            builder.ahd_classification,
            builder.missed_appointments(start_date, end_date),
            builder.guardian_visits(start_date, end_date),
            builder.who_stage
          ]

          data = builder.run(queries.reduce(&:merge))
          rtt_patients = find_rtt

          data.each do |row|
            labs = patient_labs(row['test_results'])
            patient_id = row['patient_id']
            outcome = row['outcome']

            report.total_eligible << patient_id if patient_meets_criteria?(row, labs, rtt_patients)

            if labs.keys.include?('CD4 count')
              report.total_cd4_done << patient_id
              measure, result = labs['CD4 count'].split(',')
              if measure == '<' && result.to_f <= 200
                report.total_cd4_less_than_200 << patient_id
              elsif measure == '>' && result.to_f >= 200
                report.total_cd4_greater_than_200 << patient_id
              end
            end

            if labs.keys.include?('HIV Viral load')
              measure, result = labs['HIV Viral load'].split(',')
              report.total_high_viral_load << patient_id if result.to_f > 1000 || (measure == '=' && result == 'LDL')
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

            report.deaths << patient_id if outcome == 'Patient died'
            report.transfered_out << patient_id if outcome == 'Patient transferred out'

            report.ma << patient_id if row['missed_appointment'] == 'Yes'
            report.guardian_visits << patient_id if row['guardian_visit'] == 'Yes'

            report.total_back_to_care << patient_id if patient_id.in?(rtt_patients.map { |x| x['patient_id'] })
          end
        end
      end
    end
  end
end
