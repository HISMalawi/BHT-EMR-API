# frozen_string_literal: true

module VIAService
  # Provides various summary statistics for an ART patient
  class PatientSummary
    NPID_TYPE = 'National id'
  
    include ModelUtils
  
    attr_reader :patient
    attr_reader :date
  
    def initialize(patient, date)
      @patient = patient
      @date = date
      @vmmc_service = VIAService::PatientSummary
    end
  
    def full_summary
    
        
      {
        patient_id: patient.patient_id,
        current_outcome: program_status,
        initial_via_date: "initial_via_date",
        latest_via_result: "latest_via_result"
      }
    end

    def program_status
      concept_name = ConceptName.joins("INNER JOIN program_workflow_state s ON s.concept_id=concept_name.concept_id
      INNER JOIN patient_state ps ON ps.state = s.program_workflow_state_id
      INNER JOIN patient_program p ON p.patient_program_id = ps.patient_program_id").where("p.patient_id = ?
      AND p.program_id = ? AND p.voided = 0 AND ps.voided = 0 AND s.retired = 0", 
      patient.id, 24).order("ps.date_created DESC, ps.start_date DESC").\
      group("concept_name.concept_id")

      return concept_name.blank? ? nil : concept_name.first.name
    end
  
  end

end
