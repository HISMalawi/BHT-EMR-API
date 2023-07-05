# frozen_string_literal: true

module VmmcService
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
      @vmmc_service = VmmcService::PatientSummary
    end
  
    def full_summary
    
        vitals_bp = "#{systolic_blood_pressure} / #{diastolic_blood_pressure}" 

        postop_bp = "#{postop_systolic_blood_pressure} / #{postop_diastolic_blood_pressure}"
        
      {
        patient_id: patient.patient_id,
        vitals_temperature: vitals_temperature,
        vitals_bp: vitals_bp,
        vitals_weight: vitals_weight,
        vitals_pulse: vitals_pulse,
        postop_pulse_rate: postop_pulse_rate,
        postop_bp: postop_bp,
        postop_spo: postop_spo,
        vitals_bmi: vitals_bmi
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

    def postop_pulse_rate

      pulse = Observation.joins([:encounter])
        .where(['person_id = ? AND encounter_type = ? AND obs.concept_id = ?',
          patient.id,
          EncounterType.find_by_name('Post-op review').id,
          ConceptName.find_by_name('Pulse').concept_id]
        ).order(:obs_datetime).last&.value_numeric
    end

    def postop_spo

      postop_spo = Observation.joins([:encounter])
        .where(['person_id = ? AND encounter_type = ? AND obs.concept_id = ?',
          patient.id,
          EncounterType.find_by_name('Post-op review').id,
          ConceptName.find_by_name('Blood oxygen saturation').concept_id]
        ).order(:obs_datetime).last&.value_numeric
    end

    def postop_systolic_blood_pressure
      postop_sbp = Observation.joins([:encounter])
        .where(['person_id = ? AND encounter_type = ? AND obs.concept_id = ?',
          patient.id,
          EncounterType.find_by_name('Post-op review').id,
          ConceptName.find_by_name('Systolic blood pressure').concept_id]
        ).order(:obs_datetime).last&.value_numeric.to_i
    end

    def postop_diastolic_blood_pressure
      postop_dbp = Observation.joins([:encounter])
        .where(['person_id = ? AND encounter_type = ? AND obs.concept_id = ?',
          patient.id,
          EncounterType.find_by_name('Post-op review').id,
          ConceptName.find_by_name('Diastolic blood pressure').concept_id]
        ).order(:obs_datetime).last&.value_numeric.to_i
    end

    def vitals_bmi
      bmi = Observation.joins([:encounter])
        .where(['person_id = ? AND encounter_type = ? AND obs.concept_id = ?',
          patient.id,
          EncounterType.find_by_name('Vitals').id,
          ConceptName.find_by_name('Body mass index, measured').concept_id]
        ).order(:obs_datetime).last&.value_numeric
    end
  
  end

end