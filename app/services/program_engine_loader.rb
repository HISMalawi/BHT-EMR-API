# frozen_string_literal: true

module ProgramEngineLoader
  PROGRAM_SERVICE_MODULES = {
    'HIV PROGRAM' => 'ARTService'
  }.freeze

  def self.load(program, engine_name)
    load!(program, engine_name)
  rescue NameError => e
    Rails.logger.error("Failed to load #{program.name} engine: #{engine_name} due to #{e}")
    nil
  end

  def self.load!(program, engine_name)
    "#{program_service_module(program)}::#{engine_name}".constantize
  end

  def self.program_service_module(program)
    module_name = PROGRAM_SERVICE_MODULES[program.name.upcase]

    return module_name if module_name

    root = program.name.match(/^(\w+)\s*Program$/i)[0]
    "#{root.upcase}Service"
  end
end
