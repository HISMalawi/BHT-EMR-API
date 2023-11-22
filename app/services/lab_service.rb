# frozen_string_literal: true

class LabService
  ENGINES = {
    'OPD Program' => OpdService::LabEngine
  }.freeze

  attr_accessor :program

  def initialize(program)
    @program = program
  end

  def load_engine
    engine = ENGINES[program.name]
    raise NotFoundError, "#{program.name} Lab engine not found" unless engine

    engine.new(program: program)
  end
end
