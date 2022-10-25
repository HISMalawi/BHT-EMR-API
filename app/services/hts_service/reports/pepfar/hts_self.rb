# frozen_string_literal: true

module HtsService
  module Reports
    module Pepfar
      # HTS Self report
      class HtsSelf
        attr_accessor :start_date, :end_date

        include ARTService::Reports::Pepfar::Utils

        def initialize(start_date:, end_date:)
          @start_date = start_date
          @end_date = end_date
        end

        def find_report
          report = init_report
          load_patients_into_report report, fetch_clients
          response = []
          report.each do |key, value|
            response << { age_group: key, gender: 'F', **value['F'] }
            response << { age_group: key, gender: 'M', **value['M'] }
          end
          response
        end

        private

        GENDER_TYPES = %w[F M].freeze

        def init_report
          pepfar_age_groups.each_with_object({}) do |age_group, report|
            next if age_group == 'Unknown'

            report[age_group] = GENDER_TYPES.each_with_object({}) do |gender, gender_sub_report|
              gender_sub_report[gender] = {
                directly_assisted: [],
                unassisted: [],
                self: [],
                sex_partner: [],
                other: []
              }
            end
          end
        end

        def fetch_clients
          raise NotImplementedError
        end
      end
    end
  end
end
