class AppointmentService
  ENGINES = {
    'HIV PROGRAM' => ARTService::AppointmentEngine,
    'TB PROGRAM' => TBService::AppointmentEngine,
    'ANC PROGRAM' => ANCService::AppointmentEngine,
    'VMMC PROGRAM' => VMMCService::AppointmentEngine,
    'CXCA PROGRAM' => CXCAService::AppointmentEngine
  }.freeze

  def initialize(program_id:, patient_id:, retro_date:)
    @engine = load_engine(program_id, patient_id, retro_date)
  end

  def next_appointment_date
    @engine.next_appointment_date
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

  # Creates a workflow engine for the given program_id
  def load_engine(program_id, patient_id, date)
    program = Program.find program_id
    patient = Patient.find patient_id
    date = date ? Date.strptime(date) : Date.today

    engine_name = program.name.upcase
    engine_clazz = ENGINES[engine_name]
    raise NotFoundError, "'#{engine_name}' engine not found" unless engine_clazz

    engine_clazz.new program: program, patient: patient, retro_date: date
  end
end
