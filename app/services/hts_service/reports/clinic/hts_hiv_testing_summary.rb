
module HtsService
  module Reports
    module Clinic
      class HtsHivTestingSummary

        include HtsService::Reports::HtsReportBuilder

        ACCESS_POINTS = %i[htc vct opd].freeze
        AGE_GROUPS = %i[zero_to_nine ten_to_nineteen twenty_plus].freeze
        GENDER_GROUPS =  %i[male female].freeze

        INDICATORS = {
          tested: %i[tested_for_hiv],
          tested_hiv_positive: %i[hiv_positive tested_for_hiv]
        }.freeze

        def initialize(start_date:, end_date:)
          @start_date = Date.parse(start_date).beginning_of_day
          @end_date = Date.parse(end_date).end_of_day
        end

        def data
          init_report
        end

        def init_report
          INDICATORS.each_with_object({}) do |(indicator, methods), report|
            query = methods.inject(his_patients) do |patients, method|
              send(method, patients)
            end
            ACCESS_POINTS.each do |access_point|
              AGE_GROUPS.each do |age_group|
                GENDER_GROUPS.each do |gender|
                  q = [access_point, age_group, gender].inject(query) do |patients, method|
                    send(method, patients)
                  end
                  report["#{access_point}_#{age_group}_#{indicator}_#{gender}"] = q.distinct.pluck(:patient_id)
                end
              end
            end
          end
        end
      end
    end
  end
end