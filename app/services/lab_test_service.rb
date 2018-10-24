# frozen_string_literal: true

class LabTestService
  class << self
    ENGINES = {
      'HIV PROGRAM' => ARTService::LabTestsEngine
    }.freeze

    def load_engine(program_id)
      program = Program.find program_id
      engine = ENGINES[program.concept.concept_names[0].name.upcase]
      engine.new program: program
    end
  end
end
