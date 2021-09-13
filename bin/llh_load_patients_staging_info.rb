# frozen_string_literal: true

require 'csv'
require 'logger'

concept = ->(name) { ConceptName.find_by_name!(name) }
drug = ->(name) { Drug.find_by_name!(name) }
encounter = ->(name) { EncounterType.find_by_name!(name) }
program = ->(name) { Program.find_by_name!(name) }

CD4_COUNT_BELOW_THRESHOLD = concept['CD4 Count Less than or Equal to 250']
NO = concept['Yes']
REASON_FOR_ART_ELIGIBILITY = concept['Reason for ART eligibility']
UNKNOWN = concept['Unknown']
UNSPECIFIED_WHO_STAGE_2_CONDITION = concept['Unspecified Stage 2 condition']
UNSPECIFIED_WHO_STAGE_3_CONDITION = concept['Unspecified Stage 3 condition']
UNSPECIFIED_WHO_STAGE_4_CONDITION = concept['Unspecified Stage 4 condition']
WEIGHT = concept['Weight (kg)']
WHO_STAGE = concept['WHO Stage']
WHO_STAGE_1 = concept['WHO Stage 1']
WHO_STAGE_2 = concept['WHO Stage 2']
WHO_STAGE_3 = concept['WHO Stage 3']
WHO_STAGE_4 = concept['WHO Stage 4']
WHO_STAGES_CRITERIA_PRESENT = concept['WHO Stages Criteria Present']
YES = concept['Yes']

LAMIVUDINE_150 = drug['3TC (Lamivudine 150mg tablet)']
D4T_30 = drug['d4T (Stavudine 30mg tablet)']
NVP_200 = drug['NVP (Nevirapine 200 mg tablet)']

DISPENSING_ENCOUNTER = encounter['Dispensing']
STAGING_ENCOUNTER = encounter['HIV Staging']
TREATMENT_ENCOUNTER = encounter['Treatment']

HIV_PROGRAM = program['HIV Program']

def logger
  return @logger if @logger

  @logger = Logger.new($stdout)
  @logger.level = :debug
  # Rails.logger = @logger
  # ActiveRecord::Base.logger = @logger

  @logger
end

def translate_reason_for_starting_art(patient, lh_reason)
  logger.info("Processing reason for starting for patient ##{patient.patient_id}: #{lh_reason}")
  case lh_reason
  when /CD4 Below threshold/i
    {
      WHO_STAGE => WHO_STAGE_2,
      REASON_FOR_ART_ELIGIBILITY => CD4_COUNT_BELOW_THRESHOLD,
      WHO_STAGES_CRITERIA_PRESENT => UNSPECIFIED_WHO_STAGE_2_CONDITION,
      CD4_COUNT_BELOW_THRESHOLD => YES
    }
  when /3WHO/i
    {
      WHO_STAGE => WHO_STAGE_3,
      REASON_FOR_ART_ELIGIBILITY => WHO_STAGE_3,
      WHO_STAGES_CRITERIA_PRESENT => UNSPECIFIED_WHO_STAGE_3_CONDITION
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

def translate_drugs(patient, lh_drug)
  logger.info("Processing drugs for patient ##{patient.patient_id}: #{lh_drug}")
  case lh_drug
  when /Stavudine 30 Lamivudine 150 Nevirapine 200/i then [D4T_30, LAMIVUDINE_150, NVP_200]
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
  staging = Encounter.where(type: STAGING_ENCOUNTER, patient: patient)
                     .where('encounter_datetime < DATE(?) + INTERVAL 1 DAY', date)
                     .first
  return staging if staging

  staging = encounter_service.create(program: HIV_PROGRAM, type: STAGING_ENCOUNTER, patient: patient, encounter_datetime: date)
  raise "Couldn't create staging encounter: #{staging.errors.as_json}" unless staging.errors.empty?

  staging
end

def drug_encounter(patient, date, encounter_type)
  encounter = Encounter.where(type: encounter_type, patient: patient, encounter_datetime: (date..(date + 1.day).to_date))
                       .first
  return encounter if encounter

  encounter = encounter_service.create(program: HIV_PROGRAM, type: encounter_type, patient: patient, encounter_datetime: date)
  raise "Couldn't create #{encounter_type.name} encounter: #{encounter.errors.as_json}" unless encounter.errors.empty?

  encounter
end

def patient_treatment_encounter(patient, date)
  drug_encounter(patient, date, TREATMENT_ENCOUNTER)
end

def patient_dispensing_encounter(patient, date)
  drug_encounter(patient, date, DISPENSING_ENCOUNTER)
end

def save_patient_staging_information(patient, staging_information, date)
  logger.info("Saving patient ##{patient.patient_id} staging information")
  encounter = patient_staging_encounter(patient, date)

  logger.debug("Voiding existing staging information for patient ##{patient.patient_id}")
  encounter
    .observations
    .each { |observation| observation.void('Overwritten by LLH Pre - 2010 patients import script') }

  logger.debug("Creating new staging information for patient ##{patient.patient_id}")
  staging_information.each do |question_concept, value_concept|
    Observation.create!(encounter: encounter,
                        person_id: encounter.patient_id,
                        obs_datetime: date,
                        concept_id: question_concept.concept_id,
                        value_coded: value_concept.concept_id,
                        value_text: value_concept.name)
  end
end

def make_drug_prescriptions(patient, drugs, date)
  encounter = patient_treatment_encounter(patient, date)

  drug_orders = drugs.map do |drug|
    {
      drug_inventory_id: drug.drug_id,
      start_date: date,
      auto_expire_date: (date + 30.days).to_date,
      instructions: 'AM: 1, PM: 0',
      dose: 1,
      equivalent_daily_dose: 1,
      frequency: 'ONCE A DAY (OD)',
      quantity: 30
    }
  end

  encounter.orders.each { |order| order.void('Overwritten by LLH Pre - 2010 patients import script') }

  DrugOrderService.create_drug_orders(encounter: encounter, drug_orders: drug_orders)
end

def dispense_drugs(patient, orders, date)
  logger.info("Processing drug dispensations for patient ##{patient.patient_id}")

  logger.debug("Voiding existing dispensations for patient ##{patient.patient_id}")
  patient_dispensing_encounter(patient, date)
    .observations
    .each { |observation| observation.void('Overwritten by LLH Pre - 2010 patients import script', skip_after_void: true) }

  logger.debug("Creating new dispensations for patient ##{patient.patient_id}")
  dispensations = orders.map do |order|
    {
      drug_order_id: order.order_id,
      quantity: 30,
      date: date
    }
  end

  DispensationService.create(HIV_PROGRAM,  dispensations)
end

def process_csv(csv)
  csv.each_with_index do |row, i|
    patient = Patient.find(row.fetch('patient_id'))
    art_start_date = Date.strptime(row.fetch('artstartdate'), '%d-%b-%y')
    staging_information = translate_reason_for_starting_art(patient, row.fetch('rsnstartART'))
    drugs_prescribed = translate_drugs(patient, row.fetch('Possible_Initial_ARV_Regimen'))

    logger.info("#{i} - Updating patient ##{patient.patient_id} initiated on #{art_start_date}")
    save_patient_staging_information(patient, staging_information, art_start_date)
    orders = make_drug_prescriptions(patient, drugs_prescribed, art_start_date)
    dispense_drugs(patient, orders, art_start_date)
  end
end

require 'dispensation_service'

module DispensationService
  ##
  # Disable running of background stock update job
  def self.update_stock_ledgers(*_args, **kwargs); end
end

unless $ARGV.size == 1
  warn 'Staging source file not provided...'
  warn 'USAGE: bin/rails r bin/llh_load_patients_staging_info.rb ~/Downloads/Lighthouse-patients-ARV_Regimen_Assigned share.csv'
end

CSV.open($ARGV.first, headers: true) do |csv|
  User.current = User.find_by_username!('admin')
  Location.current = Location.find_by_name!('ART Clinic')

  ApplicationRecord.transaction { process_csv(csv) }
end
