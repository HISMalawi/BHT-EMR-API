# frozen_string_literal: true

module CxcaService
  module Reports
    module Clinic
      ##
      # Common utilities for clinic reports
      module Utils
        ##
        # An array of all groups as required by Pepfar.
        def age_groups
          [
            '15-19 years',
            '20-24 years',
            '25-29 years', '30-34 years',
            '35-39 years', '40-44 years',
            '45-49 years'
          ].freeze
        end

        def moh_age_groups
          ['<25 years', '25-29 years', '30-44 years', '45-49 years', '>49 years'].freeze
        end

        def fifty_plus
          [
            '50-54 years',
            '55-59 years', '60-64 years',
            '65-69 years', '70-74 years',
            '75-79 years', '80-84 years',
            '85-89 years',
            '90 plus years'
          ].freeze
        end

        def pepfar_age_groups
          @pepfar_age_groups ||= [
            'Unknown',
            '<1 year',
            '1-4 years', '5-9 years',
            '10-14 years', '15-19 years',
            '20-24 years',
            '25-29 years', '30-34 years',
            '35-39 years', '40-44 years',
            '45-49 years', '50-54 years',
            '55-59 years', '60-64 years',
            '65-69 years', '70-74 years',
            '75-79 years', '80-84 years',
            '85-89 years',
            '90 plus years'
          ].freeze
        end
      end
    end
  end
end
