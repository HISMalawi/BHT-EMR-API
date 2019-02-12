# frozen_string_literal: true

# Viral load report
class ViralLoad
  attr_reader :name, :type, :start_date, :end_date

  def initialize(name:, type:, start_date:, end_date:)
    @name = name
    @start_date = start_date
    @end_date = end_date
    @type = type
  end

  def find_report
  end

  def build_report
  end

  private
end
