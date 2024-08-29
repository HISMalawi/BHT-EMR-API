# frozen_string_literal: true
require 'yaml'

class TbService::PatientDrugs
  delegate :get, to: :patient_observation

  def initialize (patient, date)
    @patient = patient
    @date = date
  end

  def adherence
    c_name = 'What was the patients adherence for this drug order'
    observations = get(@patient, c_name, @date)

    observations.collect do |observation|
      [observation&.order&.drug_order&.drug&.name || '', observation.value_numeric]
    end
  end

  def pills_brought
    c_name = 'Amount of drug brought to clinic'
    observations = get(@patient, c_name, @date )
    observations.collect do |observation|
      drug = observation&.order&.drug_order&.drug
      next unless drug

      [format_drug_name(drug), observation.value_numeric]
    end
  end

  def pills_dispensed
    return @pills_dispensed if @pills_dispensed
      observations = Observation.where(concept: concept('Amount dispensed'),
                                       person: @patient.person)\
                                .where('obs_datetime BETWEEN ? AND ?', *TimeUtils.day_bounds(@date))

      @pills_dispensed = observations.each_with_object({}) do |observation, pills_dispensed|
        drug = observation&.order&.drug_order&.drug
        next unless drug

        drug_name = format_drug_name(drug)
        pills_dispensed[drug_name] ||= 0
        pills_dispensed[drug_name] += observation.value_numeric
      end

    @pills_dispensed = @pills_dispensed.collect { |k, v| [k, v] }
  end

  private

  def patient_observation
    TbService::PatientObservation
  end

  def format_drug_name(drug)
    name = get_drug_short_name(drug)
    return name if not name.blank?

    match = drug.name.match(/^(.+)\s*\(.*$/)
    name = match.nil? ? drug.name : match[1]

    name = 'CPT' if name.match?('Cotrimoxazole')
    name = 'INH' if name.match?('INH')
    name
  end

  def get_drug_short_name(drug)
    begin
      drugDictionary = YAML.load_file("db/data/ntp/dr_drug_dictionary.yml")['tb_drugs']
      name = ConceptName.find_by(concept_id: drug.concept_id, concept_name_type:'FULLY_SPECIFIED').name
      drugDictionary[name]["abbreviation"]
    rescue StandardError
      nil
    end
  end
end