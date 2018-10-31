# frozen_string_literal: true

class RegimenService
  ENGINES = {
    'HIV PROGRAM' => ARTService::RegimenEngine
  }.freeze

  def initialize(program_id:)
    @engine = load_engine program_id
  end

  def find_regimens(weight: nil, age: nil, paginator: nil)
    @engine.find_regimens weight: weight, age: age, paginator: paginator
  end

  private

  def load_engine(program_id)
    program = Program.find program_id
    engine = ENGINES[program.concept.concept_names[0].name.upcase]
    engine.new program: program
  end
end
