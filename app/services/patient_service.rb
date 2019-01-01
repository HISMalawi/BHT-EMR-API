# frozen_string_literal: true

class PatientService
  include ModelUtils

  def find_by_identifier(identifier, identifier_type: nil)
    identifier_type ||= IdentifierType.find_by('National id')

    Patient.joins(:patient_identifiers).where(
      'patient_identifier.identifier_type = ? AND patient_identifier.identifier = ?',
      identifier_type.patient_identifier_type_id, identifier
    ).first
  end

  def find_patient_median_weight_and_height(patient)
    median_weight_height(patient.age_in_months, patient.person.gender)
  end

  def median_weight_height(age_in_months, gender)
    gender = (gender == 'M' ? '0' : '1')
    values = WeightHeightForAge.where(['age_in_months = ? and sex = ?', age_in_months, gender]).first
    [values.median_weight, values.median_height] if values
  end

  def drugs_orders(patient, date)
    DrugOrder.joins(:order).where(
      'orders.start_date <= ? AND patient_id = ?',
      TimeUtils.day_bounds(date)[1], patient.patient_id
    ).order('orders.start_date DESC')
  end

  def assign_patient_filing_number(patient, filing_number = nil)
    archived_identifier = nil

    if filing_number
      archived_identifier = filing_number_service.archive_patient_by_filing_number(filing_number)
    else
      filing_number ||= filing_number_service.find_available_filing_number('Filing number')
    end

    new_identifier = filing_number_service.restore_patient(patient, filing_number) if filing_number
    return nil unless new_identifier

    { new_identifier: new_identifier, archived_identifier: archived_identifier }
  end

  def current_bp_drugs(patient, date = Date.today)
    medication_concept = concept('HYPERTENSION DRUGS').concept_id
    drug_concept_ids = ConceptSet.where('concept_set = ?', medication_concept).map(&:concept_id)
    drugs = Drug.where('concept_id IN (?)', drug_concept_ids)
    drug_ids = drugs.collect(&:drug_id)
    dispensing_encounter = encounter_type('DISPENSING')

    prev_date = Encounter.joins(
      'INNER JOIN obs ON encounter.encounter_id = obs.encounter_id'
    ).where(
      "encounter.patient_id = ?
        AND value_drug IN (?) AND encounter.encounter_datetime < ?
        AND encounter.encounter_type = ?",
      patient.id, drug_ids, (date + 1.day).to_date, dispensing_encounter.id
    ).select(['encounter_datetime']).last&.encounter_datetime&.to_date

    return [] if prev_date.blank?

    dispensing_concept = concept('AMOUNT DISPENSED').concept_id
    result = Encounter.find_by_sql(
      ["SELECT obs.value_drug FROM encounter
          INNER JOIN obs ON obs.encounter_id = encounter.encounter_id
        WHERE encounter.voided = 0 AND encounter.patient_id = ?
          AND obs.value_drug IN (?) AND obs.concept_id = ?
          AND encounter.encounter_type = ? AND DATE(encounter.encounter_datetime) = ?",
       patient.id, drug_ids, dispensing_concept, dispensing_encounter.id, prev_date]
    )&.map(&:value_drug)&.uniq || []

    result.collect { |drug_id| Drug.find(drug_id) }
  end

  private

  def filing_number_service
    @filing_number_service ||= FilingNumberService.new
  end
end
