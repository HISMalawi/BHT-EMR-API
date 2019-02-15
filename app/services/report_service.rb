
class ReportService
  # A factory for workflow engines.
  ENGINES = {
    # Table mapping program concept name to engine
    'OPD PROGRAM' => OPDService::ReportEngine
  }.freeze

  def initialize(program_id:, date:)
    @engine = load_engine program_id, date
  end

  def dashboard_stats
    @engine.dashboard_stats
  end

  private

  # Creates a report engine for the given program_id and date
  def load_engine(program_id, date)
    program = Program.find program_id
    date = date ? Date.strptime(date) : Date.today

    engine_name = program.name.upcase
    engine_clazz = ENGINES[engine_name]
    raise NotFoundError, "'#{engine_name}' engine not found" unless engine_clazz

    engine_clazz.new program: program, date: date
  end
end
