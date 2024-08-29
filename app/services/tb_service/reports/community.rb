# frozen_string_literal: true

module TbService
  module Reports
    module Community
      class << self
        def report_format(indicator:)
          {
            indicator:,
            total: []
          }
        end

        def format_report(indicator:, report_data:, **_kwargs)
          data = report_format(indicator:)
          report_data&.each do |patient|
            if indicator == 'functional_sputum_sample_collection_points'
              data[:total] << patient unless data[:total].include?(patient)
              next
            end
            process_patient(patient, data)
          end
          data
        end

        def process_patient(patient, data)
          data[:total] << patient&.id unless data[:total].include?(patient&.id)
        end

        def number_of_presumptive_tb_cases_referred_from_cscp(start_date, end_date)
          query = initial_visits_query.new(start_date, end_date)
          query.referred_from_sscp
        end

        def number_of_presumptive_tb_cases_referred_from_hh_tb_screening_sites(start_date, end_date)
          query = initial_visits_query.new(start_date, end_date)
          query.referred_from_hh_tb_screening_sites
        end

        def number_of_tb_cases_diagnosed_among_sputum_collection_point_referrals(start_date, end_date)
          query = initial_visits_query.new(start_date, end_date)
          query.cases_among_sputum_collection_points
        end

        def number_of_tb_cases_diagnosed_among_referrals_from_house_to_house_tb_screening(start_date, end_date)
          query = initial_visits_query.new(start_date, end_date)
          query.cases_among_house_to_house_tb_screening
        end

        def number_of_tb_cases_diagnosed_among_referrals_from_mobile_diagnostic_units(start_date, end_date)
          query = initial_visits_query.new(start_date, end_date)
          query.cases_among_mobile_diagnostic_units
        end

        def functional_sputum_sample_collection_points(_start_date, _end_date)
          prop = GlobalProperty.find_by_property('functional_sputum_collection_points_in_catchment')
          return [] if prop.blank?

          (1..prop.property_value.to_i).to_a
        end

        def number_of_newly_established_sputum_sample_collection_points(start_date, end_date)
          quarter = get_reporting_quarter(start_date, end_date)
          prop = GlobalProperty.find_by_property("newly_established_sputum_collection_points.#{start_date.to_date.year}.#{quarter}")

          return [] if prop.blank?

          (1..prop.property_value.to_i).to_a
        end

        private

        def initial_visits_query
          TbService::TbQueries::InitialVisitsQuery
        end

        def get_reporting_quarter(start_date, end_date)
          start_year = start_date.to_date.year
          end_year = end_date.to_date.year
          quarter = 0
          if start_date.to_date == "#{start_year}-01-01".to_date && end_date.to_date == "#{end_year}-03-31".to_date
            quarter = 1
          elsif start_date.to_date == "#{start_year}-04-01".to_date && end_date == "#{end_year}-06-30".to_date
            quarter = 2
          elsif start_date.to_date == "#{start_year}-07-01".to_date && end_date.to_date == "#{end_year}-09-30".to_date
            quarter = 3
          elsif start_date.to_date == "#{start_year}-10-01".to_date && end_date.to_date == "#{end_year}-12-31".to_date
            quarter = 4
          end

          quarter
        end
      end
    end
  end
end
