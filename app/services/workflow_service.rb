# frozen_string_literal: true

class WorkflowService
  # A factory for workflow engines.
  ENGINES = {
    # Table mapping program concept name to engine
    'HIV PROGRAM' => ARTService::WorkflowEngine,
    'OPD PROGRAM' => OPDService::WorkflowEngine,
    'TB PROGRAM' => TBService::WorkflowEngine,
    'ANC PROGRAM' => ANCService::WorkflowEngine,
    'OPD PROGRAM' => OPDService::WorkflowEngine,
    'VMMC PROGRAM' => VMMCService::WorkflowEngine,
    'CXCA PROGRAM' => CXCAService::WorkflowEngine
  }.freeze

  def initialize(program_id:, patient_id:, date: nil)
    @engine = load_engine program_id, patient_id, date
  end

  def next_encounter
    @engine.next_encounter
  end

  private

  # Creates a workflow engine for the given program_id and patient_id
  def load_engine(program_id, patient_id, date)
    program = Program.find program_id
    patient = Patient.find patient_id
    date = date ? Date.strptime(date) : Date.today

    engine_name = program.name.upcase
    engine_clazz = ENGINES[engine_name]
    raise NotFoundError, "'#{engine_name}' engine not found" unless engine_clazz

    engine_clazz.new program: program, patient: patient, date: date
  end
end
