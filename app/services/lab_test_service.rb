# frozen_string_literal: true

class LabTestService
  class << self
    ENGINES = {
      'HIV PROGRAM' => ArtService::LabTestsEngine,
      'TB PROGRAM' => TbService::LabTestsEngine
    }.freeze

    def load_engine(program_id)
      program = Program.find program_id
      engine = ENGINES[program.name.upcase]
      engine.new program:
    end
  end
end
