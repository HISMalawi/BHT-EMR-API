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
      @vmmc_service = VMMCService::PatientSummary
    end
  
    def full_summary
    
        vitals_bp = "#{systolic_blood_pressure} / #{diastolic_blood_pressure}" 
        
      {
        patient_id: patient.patient_id,
        vitals_temperature: vitals_temperature,
        vitals_bp: vitals_bp,
        vitals_weight: vitals_weight,
        vitals_pulse: vitals_pulse
      }
    end

    def vitals_temperature

      temperature = Observation.joins([:encounter])
        .where(['person_id = ? AND encounter_type = ? AND obs.concept_id = ?',
          patient.id,
          EncounterType.find_by_name('Vitals').id,
          ConceptName.find_by_name('Temperature (c)').concept_id]
        ).order(:obs_datetime).last&.value_numeric
    end

    def systolic_blood_pressure
      sbp = Observation.joins([:encounter])
        .where(['person_id = ? AND encounter_type = ? AND obs.concept_id = ?',
          patient.id,
          EncounterType.find_by_name('Vitals').id,
          ConceptName.find_by_name('Systolic blood pressure').concept_id]
        ).order(:obs_datetime).last&.value_numeric.to_i
    end

    def diastolic_blood_pressure
      dbp = Observation.joins([:encounter])
        .where(['person_id = ? AND encounter_type = ? AND obs.concept_id = ?',
          patient.id,
          EncounterType.find_by_name('Vitals').id,
          ConceptName.find_by_name('Diastolic blood pressure').concept_id]
        ).order(:obs_datetime).last&.value_numeric.to_i
    end

    def vitals_weight
      weight = Observation.joins([:encounter])
        .where(['person_id = ? AND encounter_type = ? AND obs.concept_id = ?',
          patient.id,
          EncounterType.find_by_name('Vitals').id,
          ConceptName.find_by_name('Weight (kg)').concept_id]
        ).order(:obs_datetime).last&.value_numeric
    end

    def vitals_pulse
      pulse = Observation.joins([:encounter])
        .where(['person_id = ? AND encounter_type = ? AND obs.concept_id = ?',
          patient.id,
          EncounterType.find_by_name('Vitals').id,
          ConceptName.find_by_name('Pulse').concept_id]
        ).order(:obs_datetime).last&.value_numeric
    end
  
  end

end