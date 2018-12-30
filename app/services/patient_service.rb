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
end
