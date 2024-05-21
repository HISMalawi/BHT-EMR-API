# frozen_string_literal: true

module ArtService
  module Reports
    module Clinic
      # This class is responsible for generating the VL Suppression report
      class VlSupressionReport
        attr_accessor :start_date, :end_date, :occupation, :type, :report

        include ArtService::Reports::Pepfar::Utils

        def initialize(start_date:, end_date:, **kwargs)
          @start_date = start_date
          @end_date = end_date
          @occupation = kwargs[:occupation]
          @type = kwargs[:system_type] || 'poc'
        end

        def find_report
          init_report
          fetch_due_clients
          flatten_data
        end

        private

        def init_report
          @report = COHORT_REGIMENS.each_with_object({}) do |regimen, report|
            report[regimen] = {
              due_for_vl: [],
              drawn: [],
              high_vl: [],
              low_vl: []
            }
          end
          @report['N/A'] = { due_for_vl: [], drawn: [], high_vl: [], low_vl: [] }
        end

        def fetch_due_clients
          clients = coverage_service.process_due_people
          clients.each do |patient|
            regimen = patient['current_regimen']
            regimen = regimen.gsub(/(\d+[A-Za-z]*P)\z/, '\1P') if regimen.match?(/\A\d+[A-Za-z]*[^P]P\z/)
            patient['current_regimen'] = regimen
            report[regimen][:due_for_vl] << patient['patient_id']
          end
          load_patient_tests_into_report(clients)
        end

        # rubocop:disable Metrics/MethodLength
        def flatten_data
          flat_data = []
          report.each do |regimen, data|
            flat_data << {
              regimen:,
              due_for_vl: data[:due_for_vl],
              drawn: data[:drawn],
              high_vl: data[:high_vl],
              low_vl: data[:low_vl]
            }
          end
          flat_data
        end

        # rubocop:disable Metrics/AbcSize
        def load_patient_tests_into_report(clients)
          coverage_service.find_patients_with_viral_load(clients.map do |patient|
                                                           patient['patient_id']
                                                         end).each do |patient|
            # find the regimen for the patient using the clients array
            regimen = clients.find { |client| client['patient_id'] == patient['patient_id'] }['current_regimen']
            report[regimen][:drawn] << patient['patient_id']
            next unless patient['result_value']

            if patient['result_value'].casecmp?('LDL')
              report[regimen][:low_vl] << patient['patient_id']
            elsif patient['result_value'].to_i < 1000
              report[regimen][:low_vl] << patient['patient_id']
            else
              report[regimen][:high_vl] << patient['patient_id']
            end
          end
        end
        # rubocop:enable Metrics/AbcSize
        # rubocop:enable Metrics/MethodLength

        def coverage_service
          @coverage_service ||= ArtService::Reports::Pepfar::ViralLoadCoverage2.new(
            start_date:,
            end_date:,
            occupation:,
            type:
          )
        end
      end
    end
  end
end
