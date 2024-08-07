# frozen_string_literal: true

module SpineService
  # Patients sub service.
  #
  # Basically provides VMMC specific patient-centric functionality
  class PatientsEngine
    include ModelUtils

    SPINE_PROGRAM = 'Spine program'

    def initialize(program:)
      @program = program
    end

    # Retrieves given patient's status info.
    #
    # The info is just what you would get on a patient information
    # confirmation page in an VMMC application.
    def patient(patient_id, date)
      patient_summary(Patient.find(patient_id), date).full_summary
    end

    def saved_encounters(patient, date)
      Encounter.where(["DATE(encounter_datetime) = ? AND patient_id = ? AND voided = 0
                        AND program_id = ?", date.to_date.strftime('%Y-%m-%d'),
                       patient.patient_id, program(SPINE_PROGRAM).id]).collect(&:name).uniq
    end

    private

    def patient_summary(patient, date)
      PatientSummary.new patient, date
    end
  end
end
