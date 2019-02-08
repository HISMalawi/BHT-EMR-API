# frozen_string_literal: true

module ANCService
  # Patients sub service.
  #
  # Basically provides ANC specific patient-centric functionality
  class PatientsEngine
    include ModelUtils
  
    def initialize(program:)
      @program = program
    end
  
    # Retrieves given patient's status info.
    #
    # The info is just what you would get on a patient information
    # confirmation page in an ANC application.
    def patient(patient_id, date)
      #patient_summary(Patient.find(patient_id), date).full_summary
    end

    def anc_visit(patient, date)
      last_lmp = patient.encounters.joins([:observations])
                  .where(['encounter_type = ? AND obs.concept_id = ?',
                    EncounterType.find_by_name('Current pregnancy').id,
                    ConceptName.find_by_name('Last menstrual period').concept_id])
                  .last.observations.collect { 
                    |o| o.value_datetime 
                }.compact.last.to_date #rescue nil

      return [] if last_lmp.blank?

      patient.encounters.where(["DATE(encounter_datetime) >= ? 
        AND DATE(encounter_datetime) <= ? AND encounter_type = ?",
        last_lmp, date,EncounterType.find_by_name("ANC VISIT TYPE")]).collect{|e|
          e.observations.collect{|o|
            o.answer_string.to_i if o.concept.concept_names.first.name.downcase == "reason for visit"
            }.compact
        }.flatten rescue []

    end
    
  end

end
