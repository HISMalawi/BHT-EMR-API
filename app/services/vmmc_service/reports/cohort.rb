# frozen_string_literal: true

module VMMCService::Reports::Cohort
  class << self
    def sample_indicator(_start_date, _end_date)
      ActiveRecord::Base.connection.select_one(
        <<~SQL
          SELECT 1 as value
        SQL
      )['value']
    end
  end
end
