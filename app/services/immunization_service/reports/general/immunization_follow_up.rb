# frozen_string_literal: true

module ImmunizationService
  module Reports
    module General
      class ImmunizationFollowUp
        def initialize(start_date:, end_date:)
            @start_date = Date.parse(start_date).beginning_of_day
            @end_date = Date.parse(end_date).end_of_day
        end

        def data
          report = init_report
          load_patients_into_report report, fetch_clients
          response = []
        end

        private

        def init_report
          
        end

        def load_patients_into_report(report, patients)
         
        end

        def fetch_clients
          
        end


      end
    end
  end
end
