# frozen_string_literal: true

class CohortDrillDown < ActiveRecord::Base
  self.table_name = :cohort_drill_down

  belongs_to :reporting_report_design_resource, foreign_key: :reporting_report_design_resource_id
end
