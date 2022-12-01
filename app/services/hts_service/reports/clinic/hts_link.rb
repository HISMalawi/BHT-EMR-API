module HtsService
  module Reports
    module Clinic
      class HtsLink
        def initialize(start_date:, end_date:)
          @start_date = start_date
          @end_date = end_date
        end
      end
    end
  end
end