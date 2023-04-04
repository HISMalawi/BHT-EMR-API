# frozen_string_literal: true

module CXCAService::Reports::Clinic
  ##
  # Common utilities for clinic reports
  module Utils
    ##
    # An array of all groups as required by PEPFAR.
    def age_groups
      [
        "15-19 years",
        "20-24 years",
        "25-29 years", "30-34 years",
        "35-39 years", "40-44 years",
        "45-49 years",
      ].freeze
    end

    def fifty_plus
      [
        "50-54 years",
        "55-59 years", "60-64 years",
        "65-69 years", "70-74 years",
        "75-79 years", "80-84 years",
        "85-89 years",
        "90 plus years",
      ].freeze
    end
  end
end
