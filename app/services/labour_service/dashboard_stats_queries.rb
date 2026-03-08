# frozen_string_literal: true

module LabourService
  class DashboardStatsQueries
    include ModelUtils

    LOGGER = Rails.logger

    def dashboard_stats_hash
      {}
    end

    private

    def labour_program_id
      @labour_program_id ||= Program.find_by(name: 'LABOUR PROGRAM')&.id
    end

    def percentage_of(count, total)
      total.to_i.zero? ? 0.0 : (count.to_f / total * 100).round(2)
    end

    def percentage_ratio(count, total, decimals = 4)
      total.to_i.zero? ? 0.0 : (count.to_f / total).round(decimals)
    end
  end
end
