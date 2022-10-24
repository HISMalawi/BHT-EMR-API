# frozen_string_literal: true

module HtsService
  module Reports
    module Pepfar
      # HTS Index report
      class HtsIndex
        def initialize(start_date:, end_date:)
          @start_date = start_date
          @end_date = end_date
        end

        def find_report
          # throwable
          raise NotImplementedError
        end

        private

        def fetch_clients
          ActiveRecord::Base.connection.select_all <<~SQL
            SELECT o.
            FROM obs o
          SQL
        end
      end
    end
  end
end
