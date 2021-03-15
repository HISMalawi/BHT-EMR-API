# frozen_string_literal: true

class ReportType < ApplicationRecord
  self.table_name = :report_def

  has_many :reports

  validates_presence_of :name
end
