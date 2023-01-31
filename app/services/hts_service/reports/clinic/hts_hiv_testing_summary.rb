
module HtsService
  module Reports
    module Clinic
      class HtsHivTestingSummary

        include HtsService::Reports::HtsReportBuilder

        INDICATORS = {
          htc_0_to_9_tested_male: %i[htc tested_for_hiv male zero_to_nine],
          htc_10_to_19_tested_male: %i[htc tested_for_hiv male ten_to_nineteen],
          htc_20_plus_tested_male: %i[htc tested_for_hiv male twenty_plus],
          htc_0_to_9_tested_female: %i[htc tested_for_hiv female zero_to_nine],
          htc_10_to_19_tested_female: %i[htc tested_for_hiv female ten_to_nineteen],
          htc_20_plus_tested_female: %i[htc tested_for_hiv female twenty_plus],
          vct_0_to_9_tested_male: %i[vct tested_for_hiv male zero_to_nine],
          vct_10_to_19_tested_male: %i[vct tested_for_hiv male ten_to_nineteen],
          vct_20_plus_tested_male: %i[vct tested_for_hiv male twenty_plus],
          vct_0_to_9_tested_female: %i[vct tested_for_hiv female zero_to_nine],
          vct_10_to_19_tested_female: %i[vct tested_for_hiv female ten_to_nineteen],
          vct_20_plus_tested_female: %i[vct tested_for_hiv female twenty_plus],
          opd_0_to_9_tested_male: %i[opd tested_for_hiv male zero_to_nine],
          opd_10_to_19_tested_male: %i[opd tested_for_hiv male ten_to_nineteen],
          opd_20_plus_tested_male: %i[opd tested_for_hiv male twenty_plus],
          opd_0_to_9_tested_female: %i[opd tested_for_hiv female zero_to_nine],
          opd_10_to_19_tested_female: %i[opd tested_for_hiv female ten_to_nineteen],
          opd_20_plus_tested_female: %i[opd tested_for_hiv female twenty_plus],
          htc_0_to_9_tested_hiv_positive_male: %i[htc hiv_positive tested_for_hiv male zero_to_nine],
          htc_10_to_19_tested_hiv_positive_male: %i[htc hiv_positive tested_for_hiv male ten_to_nineteen],
          htc_20_plus_tested_hiv_positive_male: %i[htc hiv_positive tested_for_hiv male twenty_plus],
          htc_0_to_9_tested_hiv_positive_female: %i[htc hiv_positive tested_for_hiv female zero_to_nine],
          htc_10_to_19_tested_hiv_positive_female: %i[htc hiv_positive tested_for_hiv female ten_to_nineteen],
          htc_20_plus_tested_hiv_positive_female: %i[htc hiv_positive tested_for_hiv female twenty_plus],
          vct_0_to_9_tested_hiv_positive_male: %i[vct hiv_positive tested_for_hiv male zero_to_nine],
          vct_10_to_19_tested_hiv_positive_male: %i[vct hiv_positive tested_for_hiv male ten_to_nineteen],
          vct_20_plus_tested_hiv_positive_male: %i[vct hiv_positive tested_for_hiv male twenty_plus],
          vct_0_to_9_tested_hiv_positive_female: %i[vct hiv_positive tested_for_hiv female zero_to_nine],
          vct_10_to_19_tested_hiv_positive_female: %i[vct hiv_positive tested_for_hiv female ten_to_nineteen],
          vct_20_plus_tested_hiv_positive_female: %i[vct hiv_positive tested_for_hiv female twenty_plus],
          opd_0_to_9_tested_hiv_positive_male: %i[opd hiv_positive tested_for_hiv male zero_to_nine],
          opd_10_to_19_tested_hiv_positive_male: %i[opd hiv_positive tested_for_hiv male ten_to_nineteen],
          opd_20_plus_tested_hiv_positive_male: %i[opd hiv_positive tested_for_hiv male twenty_plus],
          opd_0_to_9_tested_hiv_positive_female: %i[opd hiv_positive tested_for_hiv female zero_to_nine],
          opd_10_to_19_tested_hiv_positive_female: %i[opd hiv_positive tested_for_hiv female ten_to_nineteen],
          opd_20_plus_tested_hiv_positive_female: %i[opd hiv_positive tested_for_hiv female twenty_plus],
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
            report[indicator] = query.pluck(:patient_id)
          end
        end
      end
    end
  end
end