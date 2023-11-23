# frozen_string_literal: true

class ProgramBarcodeService
  ENGINES = {
    'OPD PROGRAM' => OPDService::BarcodeEngine
  }.freeze

  def initialize(program:)
    clazz = ENGINES[program.name.upcase]
    @engine = clazz.new(program: program)
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
end
