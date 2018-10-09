# frozen_string_literal: true

module RegimenService
  module EngineLoader
    ENGINES = {
      'HIV PROGRAM' => ARTService::RegimenEngine
    }.freeze

    def self.load_engine(program_id)
      program = Program.find program_id
      engine = ENGINES[program.concept.concept_names[0].name.upcase]
      engine.new program: program
    end
  end
end
