class ReportingReportDesignResource < RetirableRecord
  self.table_name = :reporting_report_design_resource

  include Locatable
end