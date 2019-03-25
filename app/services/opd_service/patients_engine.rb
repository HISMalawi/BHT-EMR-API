# frozen_string_literal: true

class OPDService::PatientsEngine
  def initialize(program:)
    @program = program
  end

  def visit_summary_label(patient, date)
    OPDService::VisitLabel.new(patient, date)
  end
end
