# frozen_string_literal: true

class VMMCService::WorkflowEngine
  attr_reader :program, :patient

  def initialize(program:, patient:, date:)
    @program = program
    @patient = patient
    @date = date
  end

  def next_encounter
    'N/A'
  end
end
