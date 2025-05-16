class ProgramDashboardService
  attr_accessor :program, :date

  PROGRAMS = {
    'HIV PROGRAM' => ArtService::Dashboard
  }.freeze
  
  def initialize(program:, date:)
    @program = program
    @date = date
  end

  def dashboard
    clazz = PROGRAMS[program.name.upcase]
    raise NotFoundError, "Dashboard for #{program.name} not found" unless clazz

    clazz.new(date:).dashboard
  end
end