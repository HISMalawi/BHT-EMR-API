# frozen_string_literal: true

module WorkflowService
  # A factory for workflow engines.
  module EngineLoader
    ENGINES = {
      # Table mapping program concept name to engine
      'HIV PROGRAM' => ARTService::WorkflowEngine
    }.freeze

    class << self
      # Creates a workflow engine for the given program_id and patient_id
      #
      # Throws: PatientNotRegisteredError if engine requires patient to be registered in program
      #         EntityNotFoundError if either program or patient is not found
      def load_engine(program_id:, patient_id:, date: nil)
        program = load_program program_id
        patient = load_patient patient_id
        date = date ? Date.strptime(date) : Date.today

        engine_name = program.concept.concept_names[0].name.upcase
        engine_clazz = ENGINES[engine_name]
        raise "'#{engine_name}' engine not found" unless engine_clazz
        engine_clazz.new program: program, patient: patient, date: date
      end

      private

      def load_program(program_id)
        program = Program.find_by program_id: program_id
        raise WorkflowService::Exceptions::EntityNotFoundError,
              "Program ##{program_id} not found" unless program
        program
      end

      def load_patient(patient_id)
        patient = Patient.find_by patient_id: patient_id
        raise WorkflowService::Exceptions::EntityNotFoundError,
              "Patient ##{patient_id} not found" unless patient
        patient
      end
    end
  end
end
