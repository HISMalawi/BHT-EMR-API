# frozen_string_literal: true

class RegimenService
  ENGINES = {
    'HIV PROGRAM' => ArtService::RegimenEngine,
    'TB PROGRAM' => TbService::RegimenEngine
  }.freeze

  def initialize(program_id:)
    @engine = load_engine program_id
  end

  def method_missing(method, *args, &block)
    Rails.logger.debug "Executing missing method: #{method}"
    return @engine.send(method, *args, &block) if respond_to_missing?(method)

    super(method, *args, &block)
  end

  def respond_to_missing?(method)
    Rails.logger.debug "Engine responds to #{method}? #{@engine.respond_to?(method)}"
    @engine.respond_to?(method)
  end

  private

  def load_engine(program_id)
    program = Program.find program_id

    engine = ENGINES[program.name.upcase]
    engine.new program: program
  end
end
