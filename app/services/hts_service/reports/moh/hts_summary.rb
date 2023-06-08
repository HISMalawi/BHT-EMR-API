# frozen_string_literal: true

module HtsService
  module Reports
    module Moh
      # HTS Summary report
      class HtsSummary
        include HtsService::Reports::HtsReportBuilder
        attr_accessor :start_date, :end_date

        HIV_GROUP = concept("HIV group").concept_id

        INDICATORS = [
          { name: "hiv_group", concept_id: HIV_GROUP, join: 'LEFT'}
        ]

        def initialize(start_date:, end_date:)
          @start_date = start_date&.to_date&.beginning_of_day
          @end_date = end_date&.to_date&.end_of_day
          @data = {}
        end

        def data
          init_report
          fetch_clients_tested
          fetch_confirmatory_clients
          set_unique
          @data
        end

        private

        def init_report
          model = his_patients_rev
          INDICATORS.each do |param|
            model = ObsValueScope.call(model: model, **param)
          end
          @query = Person.connection.select_all(
            model
              .select("person.gender, person.person_id")
              .group("person.person_id")
          ).to_hash
        end

        def set_unique
          @data.each do |key, obj|
            @data[key] = obj&.map { |q| q["person_id"] }.uniq
          end
        end

        def filter_hash(key, value)
          return @query.select { |q| q[key[0]] == value && q[key[1]] == value } if key.is_a?(Array)

          @query.select { |q| q[key]&.to_s&.strip == value&.to_s&.strip }
        end

        def fetch_clients_tested
          @data["total_clients_tested_for_hiv"] = @query
          @data["new_negative"] = filter_hash("hiv_group", concept("New Negative").concept_id)
          @data["new_positive_total"] = filter_hash("hiv_group", concept("New Positive").concept_id)
          @data["new_positive_male"] = @data["new_positive_total"].select { |q| q["gender"] == "M" }
          @data["new_positive_female"] = @data["new_positive_total"].select { |q| q["gender"] == "F" }
        end

        def fetch_confirmatory_clients
          @data["confirmatory_positive_total_prev_pos_professional_test"] = filter_hash("hiv_group", concept("Confirmatory Positive").concept_id)
          @data["confirmed_positive_male"] = @data["confirmatory_positive_total_prev_pos_professional_test"].select { |q| q["gender"] == "M" }
          @data["confirmed_positive_female"] = @data["confirmatory_positive_total_prev_pos_professional_test"].select { |q| q["gender"] == "F" }

          @data["confirmatory_inconclusive_total_prev_pos_professional_test"] = filter_hash("hiv_group", concept("Confirmatory Inconclusive").concept_id)
          @data["confirmed_inconclusive_male"] = @data["confirmatory_inconclusive_total_prev_pos_professional_test"].select { |q| q["gender"] == "M" }
          @data["confirmed_inconclusive_female"] = @data["confirmatory_inconclusive_total_prev_pos_professional_test"].select { |q| q["gender"] == "F" }
          @data["new_exposed_infant"] = filter_hash("hiv_group", concept("New exposed infant").concept_id)
          @data["new_inconclusive"] = filter_hash("hiv_group", concept("New inconclusive").concept_id)
        end
      end
    end
  end
end
