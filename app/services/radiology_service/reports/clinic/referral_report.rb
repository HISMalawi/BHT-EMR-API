# frozen_string_literal: true

module RadiologyService
  module Reports
    module Clinic
      # This class is used to generate the referral report.
      class ReferralReport
        def initialize(start_date:, end_date:)
          @start_date = start_date.to_date.strftime('%Y-%m-%d 00:00:00')
          @end_date = end_date.to_date.strftime('%Y-%m-%d 23:59:59')
        end

        def data
          report
        end

        private

        def report
          ActiveRecord::Base.connection.select_all <<~SQL
            SELECT value_text clinic , count(*) total
            FROM `obs`
            INNER JOIN concept_name c ON c.concept_name_id = obs.concept_id
            WHERE obs.concept_id = (SELECT concept_id FROM concept_name WHERE name = 'Referral clinic' AND voided = 0)
            AND obs_datetime BETWEEN '#{@start_date}' AND '#{@end_date}'
            AND obs.voided = 0
            GROUP BY clinic
            ORDER BY clinic ASC
          SQL
        end
      end
    end
  end
end