# frozen_string_literal: true

require_relative 'art_engine'
require_relative 'exceptions/entity_not_found_error'

module Workflows
  # A factory for workflow engines.
  module EngineLoader
    ENGINES = {
      # Table mapping program concept name to engine
      'HIV program' => ARTEngine
    }.freeze

    class << self
      # Creates a workflow engine for the given program_id and patient_id
      #
      # Throws: PatientNotRegisteredError if engine requires patient to be registered in program
      #         EntityNotFoundError if either program or patient is not found
      def load_engine(program_id, patient_id)
        program = load_program program_id
        patient = load_patient patient_id

        engine_name = program.concept.concept_names[0].name
        engine_clazz = ENGINES[engine_name]
        raise "'#{engine_name}' engine not found" unless engine_clazz
        engine_clazz.new program, patient
      end

      private

      def load_program(program_id)
        program = Program.find_by program_id: program_id
        raise Workflows::Exceptions::EntityNotFoundError,
              "Program ##{program_id} not found" unless program
        program
      end

      def load_patient(patient_id)
        patient = Patient.find_by patient_id: patient_id
        raise Workflows::Exceptions::EntityNotFoundError,
              "Patient ##{patient_id} not found" unless patient
        patient
      end
    end
  end
end
