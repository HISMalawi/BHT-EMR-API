# frozen_string_literal: true

class ReportValue < RetirableRecord
  self.table_name = :reporting_report_design_resource

  belongs_to :report, foreign_key: :report_design_id

  validates_presence_of :name
end
