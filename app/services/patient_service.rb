# frozen_string_literal: true

class PatientService
  include ModelUtils
  include TimeUtils

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

  # Retrieves a patient's bp trail
  def patient_bp_readings_trail(patient, max_date)
    concepts = [concept('SBP'), concept('DBP')]
    readings = Observation.where(person: patient.person, concept: concepts)\
                          .where('obs_datetime < ?', (max_date + 1.day).to_date)
                          .order(obs_datetime: :desc)
    visit_bp_readings_trail(readings, patient, concepts)
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

  def assign_npid(patient)
    national_id_type = patient_identifier_type(PatientIdentifierType::NPID_TYPE_NAME)
    existing_identifiers = patient_identifiers(patient, national_id_type)
    existing_identifiers[0]

    # Force immediate execution of query. We don't want it executing after saving
    # the new identifier below
    new_identifier = next_available_npid(patient, national_id_type)

    existing_identifiers.each do |identifier|
      identifier.void("Re-assigned to new national identifier: #{new_identifier.identifier}")
    end

    { new_identifier: new_identifier, voided_identifiers: existing_identifiers }
  end

  def current_htn_drugs_summary(patient, date)
    {
      drugs: current_htn_drugs(patient, date),
      notes: htn_drug_notes(patient, date)
    }
  end

  private

  # Takes a list of BP readings and groups them into a visit trail.
  #
  # A visit trail is just a map of a day to that days most recent
  # SBP and DBP reading (NOTE: We are assuming that the visit are
  # sorted in decreasing order).
  #
  # Parameters:
  #   * readings: The readings to be grouped
  #   * patient: The patient the readings belong to
  #   * bp_concepts: An array of 'SBP' and 'DBP' concepts in that order
  def visit_bp_readings_trail(readings, patient, bp_concepts)
    readings.each_with_object({}) do |reading, trail|
      date = reading.obs_datetime.to_date
      visit = trail[date] || { date: date, sbp: nil, dbp: nil,
                               drugs: bp_drugs_received(patient, date),
                               note: bp_note_received(patient, date) }

      reading_classification = classify_bp_reading(reading, bp_concepts)

      # We are only interested in the first reading on a particular day.
      next if visit[reading_classification]

      visit[reading_classification] = reading.value_numeric if reading.value_numeric

      trail[date] = visit
    end
  end

  # Returns either 'SBP' or 'DBP' for 'systolic' and 'diastolic' readings respectively
  # depending on the concept attached to the reading.
  #
  # Parameters:
  #   * reading - An Observation to classify based on its concept
  #   * bp_concepts - An array containing the concepts 'SBP' and 'DBP' in that order.
  def classify_bp_reading(reading, bp_concepts)
    case reading.concept_id
    when bp_concepts[0].concept_id
      :sbp
    when bp_concepts[1].concept_id
      :dbp
    end
  end

  BP_DRUG_CONCEPT_NAMES = %w[Enalapril Amlodipine Hydrochlorothiazide Atenolol].freeze

  # Returns a list of BP drugs patient received on given date
  def bp_drugs_received(patient, date)
    bp_drug_concepts = Concept.joins(:concept_names)\
                              .where(concept_name: { name: BP_DRUG_CONCEPT_NAMES })
    orders = Order.joins(:encounter)\
                  .where(patient: patient, concept: bp_drug_concepts)\
                  .where('encounter_datetime BETWEEN ? AND ?', *TimeUtils.day_bounds(date))
    orders.collect { |order| order.drug_order.drug.name }
  end

  def bp_note_received(patient, date)
    Observation.where(concept: concept('Plan'), person: patient.person)\
               .where('obs_datetime BETWEEN ? AND ?', *TimeUtils.day_bounds(date))
               .order(obs_datetime: :desc)
               .first
               &.value_text
  end

  def use_dde_service?
    false
  end

  def dde_service
    @dde_service ||= DDEService.new
  end

  def filing_number_service
    @filing_number_service ||= FilingNumberService.new
  end

  # Returns all of patient's identifiers of given identifier_type
  def patient_identifiers(patient, identifier_type)
    PatientIdentifier.where(patient: patient, type: identifier_type)
  end

  # Returns the next available patient identifier for assignment
  def next_available_npid(patient, identifier_type)
    unless identifier_type.name.match?(/#{PatientIdentifierType::NPID_TYPE_NAME}/i)
      raise "Unknown identifier type: #{identifier_type.name}"
    end

    return identifier_type.next_identifier(patient: patient) unless use_dde_service?

    dde_patient_id_type = patient_identifier_type(PatientIdentifierType::DDE_ID_TYPE)
    dde_patient_id = patient_identifiers(patient, dde_patient_id_type).first&.identifier
    return dde_service.re_assign_npid(dde_patient_id) if dde_patient_id

    dde_service.register_patient(patient)
  end

  # The two methods that follow were sourced somewhere from NART/lib/patient_service.
  # They have something to do with HTN medication... That's all I know as of writing
  # this...

  def current_htn_drugs(patient, date = Date.today)
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

  HTN_DRUG_NAMES = [
    'HCZ (25mg tablet)', 'Amlodipine (5mg tablet)', 'Amlodipine (10mg tablet)',
    'Enalapril (5mg tablet)', 'Enalapril (10mg tablet)', 'Atenolol (50mg tablet)',
    'Atenolol (100mg tablet)'
  ].freeze

  def htn_drug_notes(patient, date = Date.today)
    notes_concept = concept('Notes').concept_id

    drug_ids = HTN_DRUG_NAMES.collect { |name| drug(name).drug_id }

    data = Observation.find_by_sql(
      [
        "SELECT value_text, value_drug, obs_datetime
        FROM encounter INNER JOIN obs ON obs.encounter_id = encounter.encounter_id
          WHERE encounter.encounter_type = (
            SELECT encounter_type_id
            FROM encounter_type
            WHERE name = 'HYPERTENSION MANAGEMENT' LIMIT 1
          )
          AND encounter.patient_id = ?
          AND encounter.encounter_datetime < ?
          AND obs.concept_id = ?
          AND obs.value_drug IN (?)
          AND encounter.voided = 0",
        patient.id, (date + 1.days).to_date, notes_concept, drug_ids
      ]
    )

    result = {}

    map = {
      'HCZ (25mg tablet)' => 'HCZ',
      'Amlodipine (5mg tablet)' => 'Amlodipine',
      'Amlodipine (10mg tablet)' => 'Amlodipine',
      'Enalapril (5mg tablet)' => 'Enalapril',
      'Enalapril (10mg tablet)' => 'Enalapril',
      'Atenolol (50mg tablet)' => 'Atenolol',
      'Atenolol (100mg tablet)' => 'Atenolol'
    }

    data.each do |obj|
      drug_name = Drug.find(obj.value_drug).name
      name = map[drug_name]
      next if drug_name.blank? || name.blank?

      notes = obj.value_text
      date = obj.obs_datetime.to_date

      result[name] = {} if result[name].blank?
      result[name][date] = [] if result[name][date].blank?
      result[name][date] << notes
    end

    result
  end
end
