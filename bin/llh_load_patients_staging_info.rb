# frozen_string_literal: true

require 'csv'

concept = ->(name) { ConceptName.find_by_name!(name) }
drug = ->(name) { Drug.find_by_name!(name) }

CD4_COUNT_BELOW_THRESHOLD = concept['CD4 Count Less than or Equal to 250']
UNKNOWN = concept['Unknown']
UNSPECIFIED_WHO_STAGE_3_CONDITION = concept['Unspecified Stage 3 condition']
UNSPECIFIED_WHO_STAGE_4_CONDITION = concept['Unspecified Stage 4 condition']
WEIGHT = concept['Weight (kg)']
WHO_STAGE_1 = concept['WHO Stage 1']
WHO_STAGE_3 = concept['WHO Stage 3']
WHO_STAGE_4 = concept['WHO Stage 4']

D4T_30_3TC_150 = drug['d4T/3TC (Stavudine Lamivudine 30/150 tablet)']
NVP_200 = drug['NVP (Nevirapine 200 mg tablet)']

STAGING = EncounterType.find_by_name!('HIV Staging')

def translate_reason_for_starting_art(_patient, lh_reason)
  case lh_reason
  when /CD4 Below threshold/i
    {
      WHO_STAGE => WHO_STAGE_2,
      REASON_FOR_ART_ELIGIBILITY => CD4_COUNT_BELOW_THRESHOLD,
      WHO_STAGES_CRITERIA_PRESENT => UNSPECIFIED_STAGE_2_CONDITION,
      CD4_COUNT_BELOW_THRESHOLD => YES
    }
  when /3WHO/i
    {
      WHO_STAGE => WHO_STAGE_3,
      REASON_FOR_ART_ELIGIBILITY => WHO_STAGE_3,
      WHO_STAGES_CRITERIA_PRESENT => UNSPECIFIED_WHO_STAGE_3_CONDITION]
    }
  when /4WHO/i
    {
      WHO_STAGE => WHO_STAGE_4,
      REASON_FOR_ART_ELIGIBILITY => WHO_STAGE_4,
      WHO_STAGES_CRITERIA_PRESENT => UNSPECIFIED_WHO_STAGE_4_CONDITION
    }
  when /^\s*$/, nil
    {
      WHO_STAGE => UNKNOWN,
      REASON_FOR_ART_ELIGIBILITY => UNKNOWN,
      WHO_STAGES_CRITERIA_PRESENT => UNKNOWN
    }
  else raise "Unknown reason for starting ART: #{lh_reason}"
  end
end

def translate_drugs(lh_drug)
  case lh_drug
  when /Stavudine 30 Lamivudine 150 Nevirapine 200/i then [D4T_30_3TC_150, NVP_200]
  else raise "Unknown drug name: #{lh_drug}"
  end
end

def patient_weight(patient, date)
  obs = Observation.where(person_id: patient.id, concept_id: WEIGHT.concept_id)
                   .where('obs_datetime < DATE(?) + INTERVAL 1 DAY', date)
                   .first

  obs&.value_numeric || obs&.value_text&.to_f
end

def encounter_service
  @encounter_service ||= EncounterService.new
end

def patient_staging_encounter(patient, date)
  staging = Encounter.where(type: STAGING, person_id: patient.patient_id)
                     .where('encounter_datetime < DATE(?) + INTERVAL 1 DAY', date)
                     .first
  return staging if staging

  staging = encounter_service.create(type: STAGING, patient: patient, encounter_datetime: date)
  raise "Couldn't create staging encounter: #{staging.errors.as_json}" unless staging.errors.empty?

  staging
end

def save_observations(encounter, date, observations)
  Observation.transaction do
    observations.each do |question_concept, value_concept|
      Observation.create!(encounter: encounter,
                          person_id: encounter.person_id,
                          obs_datetime: date,
                          concept_id: question_concept.concept_id,
                          value_coded: value_concept.concept_id)
    end
  end
end

def save_patient_staging_information(patient, date, reason_for_starting_concepts)
  encounter = patient_staging_encounter(patient, date)

  save_observations(encounter, date, reason_for_starting_concepts)
end

unless $ARGV.size == 1
  warn 'Staging source file not provided...'
  warn 'USAGE: bin/rails r bin/llh_load_patients_staging_info.rb ~/Downloads/Lighthouse-patients-ARV_Regimen_Assigned share.csv'
end

CSV.open($ARGV.first, headers: true) do |csv|
  csv.each do |row|
    patient = Patient.find(row.fetch('patient_id'))
    art_start_date = Date.strptime(row.fetch('artstartdate'), '%d-%b-%y')
    who_stage, reason_for_starting = translate_reason_for_starting_art(patient, row.fetch('rsnstartART'))
    drugs_prescribed = translate_drugs(row.fetch('Possible_Initial_ARV_Regimen'))

    pp(patient_id: patient.id,
       weight: patient_weight(patient, art_start_date),
       art_start_date: art_start_date,
       who_stage: who_stage,
       reason_for_starting: reason_for_starting,
       drugs_prescribed: drugs_prescribed)

    # save_patient_staging_information(patient, who_stage, reason_for_starting)
    # save_prescription(patient, drugs_received)
    # save_dispensation(patient, drugs_received.map { |drug| [drug.drug_id, 30] })
  end
end
