# frozen_string_literal: true

module VMMCService
  # Provides various summary statistics for an ART patient
  class PatientSummary
    NPID_TYPE = 'National id'
    ARV_NO_TYPE = 'ARV Number'
  
    SECONDS_IN_MONTH = 2_592_000
  
    include ModelUtils
  
    attr_reader :patient
    attr_reader :date
  
    def initialize(patient, date)
      @patient = patient
      @date = date
    end
  
    def full_summary
        
      {
        patient_id: patient.patient_id,
        current_outcome: "",
        residence: ""
      }
    end
  
  end

end