# frozen_string_literal: true

module HTSService

  class PatientsEngine
    include ModelUtils

    HtsProgram = Program.find_by name: 'HTC PROGRAM'

    def initialize(program:)
      @program = program
    end


    def patient patient_id, date
      patient_summary(Patient.find(patient_id), date).full_summary
    end


    private

    def patient_summary(patient, date)
      PatientsSummary.new patient, date
    end
  end
end