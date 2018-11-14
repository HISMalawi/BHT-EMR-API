# frozen_string_literal: true

class Report < RetirableRecord
  self.table_name = :reporting_report_design

  belongs_to :type, foreign_key: :report_definition_id, class_name: 'ReportType'
  has_many :values, class_name: 'ReportValue'
end
