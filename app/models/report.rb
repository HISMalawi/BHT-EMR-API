# frozen_string_literal: true

class Report < RetirableRecord
  self.table_name = :reporting_report_design

  belongs_to :type, foreign_key: :report_definition_id, class_name: 'ReportType'
  has_many :values, class_name: 'ReportValue',
                    foreign_key: :report_design_id,
                    dependent: :delete_all

  after_void :void_values

  def as_json(options = {})
    super(options.merge(
      include: { type: {}, values: {} }
    ))
  end

  def void_values(reason)
    values.each do |value|
      value.void(reason)
    end
  end
end
