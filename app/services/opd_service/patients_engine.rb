# frozen_string_literal: true

class OPDService::PatientsEngine
  def initialize(program:)
    @program = program
  end

  def visit_summary_label(patient, date)
    OPDService::VisitLabel.new(patient, date)
  end
  
  # Retrieves given patient's status info.
  #
  # The info is just what you would get on a patient information
  # confirmation page in an ART application.
  def patient(patient_id, date)
    patient_summary(Patient.find(patient_id), date).full_summary
  end

  def patient_summary(patient, date)
    PatientSummary.new patient, date
  end

end
