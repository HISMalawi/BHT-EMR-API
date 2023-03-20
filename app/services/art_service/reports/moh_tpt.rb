# frozen_string_literal: true

module ArtService
  module Reports
    # This class generates the MOH TPT report
    class MohTpt
      attr_reader :start_date, :end_date

      def initialize(start_date:, **_kwarg)
        @start_date = start_date - 9.months
        @end_date = start_date + 3.months
      end

      def find_report
        report
      end

      private

      GENDERS = %w[FEMALE MALE].freeze
      AGE_GROUPS = ['<1 year', '1-4 years', '5-9 years', '10-14 years', '15-19 years', '20-24 years', '25-29 years', '30-34 years', '35-39 years', '40-44 years', '45-49 years', '50-54 years', '55-59 years', '60-64 years', '65-69 years', '70-74 years', '75-79 years', '80-84 years', '85-89 years', '90 plus years'].freeze

      def init_report
        AGE_GROUPS.each_with_object({}) do |age_group, report|
          next if age_group == 'Unknown'

          report[age_group] = GENDERS.each_with_object({}) do |gender, tpt_report|
            tpt_report[gender] = {
              initiated_art: [],
              initiated_tpt: [],
              completed_tpt: [],
              died: [],
              defaulted: [],
              stopped_art: [],
              transfer_out: [],
              confirmed_tb: [],
              pregnant: []
            }
          end
        end
      end
    end
  end
end
