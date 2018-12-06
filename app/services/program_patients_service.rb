class ProgramPatientsService
  ENGINES = {
    'HIV PROGRAM' => ARTService::PatientsEngine
  }.freeze

  def initialize(program:)
    clazz = ENGINES[program.concept.concept_names[0].name.upcase]
    @engine = clazz.new(program: program)
  end

  def method_missing(method, *args, &block)
    puts "Executing missing method: #{method}"
    return @engine.send(method, *args, &block) if respond_to_missing?(method)

    super(method, *args, &block)
  end

  def respond_to_missing?(method)
    puts "Engine responds to #{method}? #{@engine.respond_to?(method)}"
    @engine.respond_to?(method)
  end
end
