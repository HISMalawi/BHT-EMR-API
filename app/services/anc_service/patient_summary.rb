# frozen_string_literal: true

module ANCService
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
      @art_service = ARTService::PatientSummary
    end
  
    def full_summary
        
      {
        patient_id: patient.patient_id,
        current_outcome: "On treatment",
        residence: "",
        date_of_lnmp: date_of_lnmp,
        anc_visits: number_of_visits,
        fundus: fundus
      }
    end

    def date_of_lnmp
      last_lmp = patient.encounters.joins([:observations])
        .where(['encounter_type = ? AND obs.concept_id = ?',
          EncounterType.find_by_name('Current pregnancy').id,
          ConceptName.find_by_name('Last menstrual period').concept_id])
        .last.observations.collect { 
          |o| o.value_datetime 
        }.compact.last.to_date rescue nil
      
    end

    def number_of_visits
      lmp_date = date_of_lnmp

      anc_visits = patient.encounters.joins([:observations])
        .where(['encounter_type = ? AND obs.concept_id = ?
            AND encounter_datetime > ?',
          EncounterType.find_by_name('ANC Visit Type').id,
          ConceptName.find_by_name('Reason for visit').concept_id,
          lmp_date])
        .last.observations.collect { 
          |o| o.value_numeric 
        }.compact.length rescue nil
      
    end

    def fundus
      lmp_date = date_of_lnmp
      fundus = patient.encounters.joins([:observations])
        .where(["encounter_type = ? AND obs.concept_id = ?
            AND encounter_datetime > ?",
          EncounterType.find_by_name('Current pregnancy').id,
          ConceptName.find_by_name('week of first visit').concept_id,
          lmp_date])
        .last.observations.collect {|o|
          o.value_numeric
        }.compact.last.to_i rescue nil
    end

  end
end