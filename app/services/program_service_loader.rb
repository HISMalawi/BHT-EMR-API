# frozen_string_literal: true

##
# Loads engines/services for various programs.
#
# Example:
#   >>> TBPatientSummary = ProgramServiceLoader.load(Program.find_by_name!('TB Program'), 'PatientSummary')
#   >>> patient_summary = TBPatientSummary.new
#   >>> patient_summary.current_outcome # prints current outcome for patient in TB program
module ProgramServiceLoader
  PROGRAM_NAMESPACES = {
    'HIV PROGRAM' => 'ARTService'
  }.freeze

  def self.load(program, service_name)
    "#{program_namespace(program)}::#{service_name}".constantize
  rescue NameError => e
    Rails.logger.error("Failed to load service #{program&.name}::#{service_name}: #{e}")
    raise NotFoundError, "#{program.name} does not implement service #{service_name}"
  end

  def self.program_namespace(program)
    namespace = PROGRAM_NAMESPACES[program.name.upcase]

    return namespace if namespace

    program_name = program.name.gsub(/\s+Program$/i).upcase

    "#{program_name}Service"
  end
end
