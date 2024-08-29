# frozen_string_literal: true

class PatientService
  include ModelUtils
  include TimeUtils

  def create_patient(program, person, malawi_national_id = nil)
    ActiveRecord::Base.transaction do
      patient = Patient.create(patient_id: person.id)
      unless patient.errors.empty?
        raise "Could not create patient for person ##{person.id} due to #{patient.errors.as_json}"
      end

      if use_dde_service?
        begin
          assign_patient_dde_npid(patient, program)
        rescue StandardError
          create_local_npid(patient, malawi_national_id)
        end
      else
        create_local_npid(patient, malawi_national_id)
      end

      patient.reload
      patient
    end
  end

  # method to create local npid
  def create_local_npid(patient, malawi_national_id)
    assign_patient_v3_npid(patient)
    assign_patient_v28_malawiNid(patient, malawi_national_id) if malawi_national_id.present?
  end

  ##
  # Voids all patient records across all programs patient exists
  def void_patient(patient, reason, daemonize: true)
    reason = reason&.strip
    raise InvalidParameterError, 'Please provide a void reason' if reason.blank?

    if daemonize
      VoidPatientJob.perform_later(patient.patient_id, reason, User.current.user_id)
      return nil
    end

    void_params = { voided: true, date_voided: Date.today, voided_by: User.current.user_id, void_reason: reason }

    Patient.transaction do
      Rails.logger.info("Voiding all records for patient ##{patient.patient_id}")

      # Void main patient trunk
      [Observation, Order, Encounter, PatientState, PatientProgram, PatientIdentifier, Patient].each do |model|
        if model == Observation then model.where(person_id: patient.patient_id)
        elsif model == PatientState then model.joins(:patient_program).merge(PatientProgram.where(patient:))
        elsif model == Patient then model.where(patient_id: patient.patient_id)
        else
          model.where(patient:)
        end.update_all(void_params)
      end

      # Void person details
      [PersonName, PersonAddress, PersonAttribute, Person].map do |model|
        model.where(person_id: patient.patient_id).update_all(void_params)
      end

      program = PatientProgram.unscoped.find_by(patient:)&.program || Program.first
      dde_service(program).void_patient(patient.reload, reason) if DdeService.dde_enabled?
    end
  end

  # Change patient's person id
  #
  # WARNING: THIS IS A DANGEROUS OPERATION...
  def update_patient(program, patient, person_id = nil)
    if person_id
      patient.person_id = person_id
      raise "Could not update patient patient_id ##{patient_id} due to #{patient.errors.as_json}" unless patient.save
    end

    dde_service(program).update_patient(patient) if use_dde_service? && dde_patient?(patient)

    patient
  end

  def find_patients_by_npid(npid, voided: false)
    find_patients_by_identifier(npid, *npid_identifier_types.to_a, voided:)
  end

  def find_patients_by_name_and_gender(given_name, middle_name = nil, family_name, gender)
    person_service = PersonService.new
    people = person_service.find_people_by_name_and_gender(given_name, middle_name, family_name, gender)
    Patient.joins(:person).merge(people)
  end

  def find_patient_median_weight_and_height(patient)
    median_weight_height(patient.age_in_months, patient.person.gender)
  end

  def find_patients_by_identifier(identifier, *identifier_types, voided: false)
    Patient.joins('INNER JOIN patient_identifier USING (patient_id)')
           .where(patient_identifier: { identifier:, identifier_type: identifier_types.collect(&:id),
                                        voided: })
           .distinct
  end

  def find_patient_visit_dates(patient, program = nil, include_defaulter_dates = nil, date = nil)
    patient_id = ActiveRecord::Base.connection.quote(patient.id)
    program_id = program ? ActiveRecord::Base.connection.quote(program.id) : nil
    date ||= Date.today

    return find_los_visit_dates(patient_id, date) if program_id == '23'

    rows = ActiveRecord::Base.connection.select_all <<-SQL
      SELECT DISTINCT DATE(encounter_datetime) AS visit_date
      FROM encounter
      WHERE patient_id = #{patient_id} AND voided = 0 #{if program_id
                                                          "AND program_id = #{program_id}"
                                                        end} AND encounter_datetime < DATE('#{date}') + INTERVAL 1 DAY
      AND encounter_type NOT IN (#{EncounterType.where(name: ['LAB', 'LAB ORDERS', 'LAB RESULTS']).select(:encounter_type_id).to_sql})
      GROUP BY visit_date
      ORDER BY visit_date DESC
    SQL

    visit_dates = rows.collect { |row| row['visit_date'].to_date }
    if !visit_dates.blank? && (program_id.blank? ? false : (program_id.to_i == 1)) && include_defaulter_dates
      # Starting from the initial visit date, we add 1+ month while checking if the patient defaulted.
      # if we find that the patient has a defualter date we add it to the array of visit dates.
      initial_visit_date = visit_dates.last.to_date

      while initial_visit_date < Date.today
        initial_visit_date += 1.month
        defaulter_date = ActiveRecord::Base.connection.select_one <<~SQL
          SELECT current_defaulter_date(#{patient_id}, DATE('#{initial_visit_date}')) as defaulter_date;
        SQL
        next unless !defaulter_date['defaulter_date'].blank? && check_defaulter_period(defaulter_date['defaulter_date'],
                                                                                       patient_id, program_id)

        visit_dates << defaulter_date['defaulter_date'].to_date
        visit_dates.uniq!
      end

      # add program state start date to the visit dates
      # if the patient has multiple HIV programs (should not happen but ...) we loop through them and get all state dates
      patient.patient_programs.where(program_id:).each do |pro|
        pro.patient_states.map do |state|
          visit_dates << state.start_date
          visit_dates.uniq!
        end
      end

      # We sort the dates array to make sure we start with the most recent date
      visit_dates = visit_dates.sort { |a, b| b.to_date <=> a.to_date }
    end

    visit_dates.select { |record| record.to_date <= date }
  end

  def find_los_visit_dates(patient, date = nil)
    rows = ActiveRecord::Base.connection.select_all <<~SQL
      SELECT DISTINCT DATE(o.start_date) AS visit_date FROM orders o
      INNER JOIN order_type ot ON ot.order_type_id = o.order_type_id AND ot.name = 'Lab' AND ot.retired = 0
      WHERE o.patient_id = #{patient} AND o.voided = 0 AND o.start_date < DATE('#{date}') + INTERVAL 1 DAY
      ORDER BY visit_date DESC
    SQL
    rows.collect { |row| row['visit_date'].to_date }
  end

  # method to fetch patient state that is between the defaulter date
  def check_defaulter_period(defaulter_date, patient_id, program_id)
    states = adverse_outcomes
    previous_visit = fetch_previous_visit(defaulter_date, patient_id, program_id)['visit_date']
    result = ActiveRecord::Base.connection.select_one <<~SQL
      SELECT start_date, end_date FROM patient_state
      INNER JOIN patient_program ON patient_state.patient_program_id = patient_program.patient_program_id AND patient_program.voided = 0
      WHERE patient_program.patient_id = #{patient_id}
      AND patient_state.state IN (#{states.map { |state| state['program_workflow_state_id'] }.join(',')})
      AND patient_state.voided = 0
      AND start_date >= DATE('#{previous_visit}')
      AND start_date <= DATE('#{defaulter_date}')
    SQL
    return true if result.blank?

    start_date = result['start_date']
    # check if this record has an end date for better result
    end_date = result['end_date'].blank? ? fetch_next_state_start_date(start_date, patient_id) : result['end_date']

    return false if end_date.blank?

    !defaulter_date.to_date.between?(start_date.to_date, end_date.to_date)
  end

  def fetch_next_state_start_date(state_date, patient_id)
    result = ActiveRecord::Base.connection.select_one <<~SQL
      SELECT start_date FROM patient_state
      INNER JOIN patient_program ON patient_state.patient_program_id = patient_program.patient_program_id AND patient_program.voided = 0
      WHERE patient_program.patient_id = #{patient_id}
      AND patient_state.voided = 0
      AND start_date > DATE('#{state_date}')
      ORDER BY start_date ASC
    SQL
    result.blank? ? nil : result['start_date']
  end

  def fetch_previous_visit(defaulter_date, patient_id, program_id)
    ActiveRecord::Base.connection.select_one <<-SQL
      SELECT DISTINCT DATE(encounter_datetime) AS visit_date
      FROM encounter
      WHERE patient_id = #{patient_id} AND voided = 0
      AND DATE(encounter_datetime) < DATE('#{defaulter_date}') #{"AND program_id = #{program_id}" if program_id}
      GROUP BY visit_date
      ORDER BY visit_date DESC
    SQL
  end

  def adverse_outcomes
    ProgramWorkflowState.joins(:program_workflow)
                        .where(initial: 0, terminal: 1,
                               program_workflow: { program_id: Program.where(name: 'HIV Program') })
                        .select(:program_workflow_state_id)
  end

  def median_weight_height(age_in_months, gender)
    gender = (gender == 'M' ? '0' : '1')
    values = WeightHeightForAge.where(['age_in_months = ? and sex = ?', age_in_months, gender]).first
    [values.median_weight, values.median_height] if values
  end

  def drugs_orders(patient, date)
    DrugOrder.joins(:order).where(
      'orders.start_date <= ? AND patient_id = ? AND quantity IS NOT NULL',
      TimeUtils.day_bounds(date)[1], patient.patient_id
    ).order('orders.start_date DESC')
  end

  def drugs_orders_by_program(patient, date, program_id: nil)
    DrugOrder.joins(order: :encounter).where(
      'orders.start_date <= ? AND orders.patient_id = ? AND quantity IS NOT NULL AND encounter.program_id = ?',
      TimeUtils.day_bounds(date)[1], patient.patient_id, program_id
    ).order('orders.start_date DESC')
  end

  # Last drugs received
  def patient_last_drugs_received(patient, ref_date, program_id: nil)
    dispensing_encounter_query = Encounter.joins(:type)
    dispensing_encounter_query.where(program_id:) if program_id
    dispensing_encounter = dispensing_encounter_query.where(
      'encounter_type.name = ? AND encounter.patient_id = ?
        AND DATE(encounter_datetime) <= DATE(?)',
      'DISPENSING', patient.patient_id, ref_date
    ).order(encounter_datetime: :desc).first

    return [] unless dispensing_encounter

    # HACK: Group orders in a map first to eliminate duplicates which can
    # be created when a drug is scanned twice.
    (dispensing_encounter.observations.each_with_object({}) do |obs, drug_map|
      next unless obs.value_drug || drug_map.key?(obs.value_drug)

      order = obs.order
      next unless order&.drug_order&.quantity

      drug_map[obs.value_drug] = order.drug_order
    end).values
  end

  # lab orders made for a patient
  def recent_lab_orders(patient_id:, program_id:, reference_date:)
    lab_order_encounter = encounter_type('Lab Orders')
    Encounter.where('encounter_type = ? AND patient_id = ? AND encounter_datetime >= ? AND program_id = ?',
                    lab_order_encounter.encounter_type_id,
                    patient_id,
                    reference_date,
                    program_id)\
             .order(encounter_datetime: :desc)
  end

  # Last drugs pill count
  def patient_last_drugs_pill_count(patient, ref_date, program_id: nil)
    program = Program.find(program_id) if program_id
    concept_name = ConceptName.find_by_name('Number of tablets brought to clinic')
    optimize_concept = ConceptName.find_by_name('Appointment type')
    return [] if program.blank?

    pill_counts = Observation.joins(:encounter).where(
      'program_id = ? AND encounter.patient_id = ?
        AND DATE(encounter_datetime) = DATE(?) AND concept_id = ?',
      program.id, patient.patient_id, ref_date, concept_name.concept_id
    ).order('encounter.encounter_datetime DESC')

    optimize = Observation.joins(:encounter).where(
      'program_id = ? AND encounter.patient_id = ?
        AND DATE(encounter_datetime) = DATE(?) AND concept_id = ? AND value_text = ?',
      program.id, patient.patient_id, ref_date, optimize_concept.concept_id, 'Optimize - including hanging pills'
    ).order('encounter.encounter_datetime DESC')

    return [] unless pill_counts
    return [] if optimize.blank?

    values = {}

    pill_counts.each do |obs|
      next unless obs.order

      drug_order = obs.order.drug_order
      values[drug_order.drug_inventory_id] = obs.value_numeric
    end

    values
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

    { new_identifier:, archived_identifier: }
  end

  # Returns a patient's past filing numbers
  def filing_number_history(patient)
    PatientIdentifier.unscoped.where(
      voided: true,
      patient:,
      type: [patient_identifier_type('Filing number'),
             patient_identifier_type('Archived filing number')]
    )
  end

  def assign_npid(patient, program_id)
    national_id_type = patient_identifier_type(PatientIdentifierType::NPID_TYPE_NAME)
    existing_identifiers = patient_identifiers(patient, national_id_type)
    existing_identifiers[0]

    # Force immediate execution of query. We don't want it executing after saving
    # the new identifier below
    new_identifier = next_available_npid(patient:, identifier_type: national_id_type, program_id:)

    existing_identifiers.each do |identifier|
      identifier.void("Re-assigned to new national identifier: #{new_identifier.class.name === 'PatientIdentifier' ? new_identifier.identifier : new_identifier.identifier(national_id_type.name)}")
    end

    { new_identifier:, voided_identifiers: existing_identifiers }
  end

  def most_recent_lab_order(patient_id:, program_id:, date:)
    outcome_date = patient_last_outcome_date(patient_id, program_id, date)
    Encounter.joins(:observations)
             .where(type: encounter_type('Lab Orders'),
                    patient_id: patient_id,
                    program_id: program_id)
              .where(obs: {concept_id: concept('Test type').concept_id})
              .where('obs.obs_datetime >= ? AND DATE(obs.obs_datetime) <= DATE(?)', outcome_date, date)
              .order(encounter_datetime: :desc)
              .first
  end

  def current_htn_drugs_summary(patient, date)
    {
      drugs: current_htn_drugs(patient, date),
      notes: htn_drug_notes(patient, date)
    }
  end

  def last_htn_drugs_received_summary(patient, date)
    last_htn_drugs_received(patient, date)
  end

  def update_remaining_bp_drugs(patient, date, drug, pills)
    update_remaining_drugs(patient, date, drug, pills)
  end

  # Source: NART/models/patients#patient_eligible_for_htn_screening
  def patient_eligible_for_htn_screening(patient, date = Date.today)
    threshold = global_property('htn.screening.age.threshold')&.property_value.to_i
    sbp_threshold = global_property('htn.systolic.threshold')&.property_value.to_i
    dbp_threshold = global_property('htn.diastolic.threshold')&.property_value.to_i

    if patient.age(today: date) >= threshold || patient.programs.map(&:name).include?('HYPERTENSION PROGRAM')

      htn_program = Program.find_by_name('HYPERTENSION PROGRAM')

      patient_program = enrolled_on_program(patient, htn_program.id, date, false)

      if patient_program.blank?
        # When patient has no HTN program
        last_check = last_bp_readings(patient, date)

        if last_check.blank?
          true # patient has never had their BP checked
        elsif last_check[:sbp].to_i >= sbp_threshold || last_check[:dbp].to_i >= dbp_threshold
          true # patient had high BP readings at last visit
        else
          (date.to_date - last_check[:max_date].to_date).to_i >= 365
        end
      else
        # Get plan

        plan_concept = Concept.find_by_name('Plan').id
        plan = Observation.where(['person_id = ? AND concept_id = ? AND obs_datetime <= ?', patient.id, plan_concept,
                                  date.strftime('%Y-%m-%d 23:59:59').to_time]).order('obs_datetime DESC').first
        if plan.blank?
          true
        elsif plan.value_text.match(/ANNUAL/i)
          (date.to_date - plan.obs_datetime.to_date).to_i >= 365
        else
          true # patient requires active screening
        end

      end
    else
      false
    end
  end

  # Source: NART/controllers/htn_encounter_controller#create
  def update_or_create_htn_state(patient, state, date)
    htn_program = Program.find_by_name('HYPERTENSION PROGRAM')
    # get state id
    state = ProgramWorkflowState.where(['program_workflow_id = ? AND concept_id in (?)',
                                        ProgramWorkflow.where(['program_id = ?', htn_program.id]).first.id,
                                        ConceptName.where(name: state).collect(&:concept_id)]).first.id
    return if state.blank?

    patient_program = PatientProgram.where(['patient_id = ? AND program_id = ? AND date_enrolled <= ?',
                                            patient.patient_id, htn_program.id, date]).first

    state_within_range = PatientState.where(['patient_program_id = ? AND state = ? AND start_date <= ? AND end_date >= ?',
                                             patient_program.id, state, date, date]).first

    return unless state_within_range.blank?

    last_state = PatientState.where(['patient_program_id = ? AND start_date <= ? ',
                                     patient_program.id, date]).order('start_date ASC').last
    unless last_state.blank?
      last_state.end_date = date
      last_state.save
    end

    state_after = PatientState.where(['patient_program_id = ? AND start_date >= ? ',
                                      patient_program.id, date]).order('start_date ASC').last

    new_state = PatientState.new(patient_program_id: patient_program.id,
                                 start_date: date, state:)
    new_state.end_date = state_after.start_date unless state_after.blank?
    new_state.save
  end

  def fetch_full_visit(patient, program = nil, visit_date)
    patient_id = ActiveRecord::Base.connection.quote(patient.id)
    program ? ActiveRecord::Base.connection.quote(program.id) : nil

    medication = ActiveRecord::Base.connection.select_all <<-SQL
      SELECT
          o.patient_id, o.start_date, o.auto_expire_date,
          d.name, t.quantity quantity
      FROM person p
      INNER JOIN orders o ON o.patient_id = p.person_id
      INNER JOIN drug_order t ON o.order_id = t.order_id
      INNER JOIN drug d ON d.drug_id = t.drug_inventory_id
      INNER JOIN concept_set s ON s.concept_id = d.concept_id AND s.concept_set=1085
      INNER JOIN encounter e ON e.patient_id =  o.patient_id
      WHERE o.voided = 0 AND DATE(o.start_date) = DATE('#{visit_date}')
      AND o.patient_id = #{patient_id} AND e.encounter_type = 54
      AND e.program_id = 1 GROUP BY t.drug_inventory_id;
    SQL

    medication_given = []

    unless medication.blank?
      current_regimen = ActiveRecord::Base.connection.select_one <<-SQL
        SELECT patient_current_regimen(#{patient_id}, DATE('#{visit_date}')) regimen;
      SQL

      medication.each do |m|
        medication_given << {
          medication: m['name'],
          quantity: m['quantity']
        }
      end

    end

    current_outcome = ActiveRecord::Base.connection.select_one <<-SQL
      SELECT patient_outcome(#{patient_id}, DATE('#{visit_date}')) outcome;
    SQL

    current_weight = ActiveRecord::Base.connection.select_one <<-SQL
      SELECT  IF(value_numeric is null ,value_text, value_numeric) weight
      FROM obs WHERE person_id = #{patient_id}
      AND voided = 0 AND DATE(obs_datetime) = DATE('#{visit_date}')
      AND concept_id = 5089 ORDER BY date_created DESC LIMIT 1;
    SQL

    current_height = ActiveRecord::Base.connection.select_one <<-SQL
      SELECT  IF(value_numeric is null ,value_text, value_numeric) height
      FROM obs WHERE person_id = #{patient_id}
      AND voided = 0 AND DATE(obs_datetime) = DATE('#{visit_date}')
      AND concept_id = 5090 ORDER BY date_created DESC LIMIT 1;
    SQL

    patient_available = ActiveRecord::Base.connection.select_one <<-SQL
      SELECT IF(value_coded = 1065 , "YES", "N/A") pa
      FROM obs WHERE concept_id = 1805 AND person_id = #{patient_id}
      AND voided  = 0 AND DATE(obs_datetime) = DATE('#{visit_date}')
      ORDER BY date_created DESC LIMIT 1;
    SQL

    guardian_available = ActiveRecord::Base.connection.select_one <<-SQL
      SELECT IF(value_coded = 1065 , "YES", "N/A") pa
      FROM obs WHERE concept_id = 2122 AND person_id = #{patient_id}
      AND voided  = 0 AND DATE(obs_datetime) = DATE('#{visit_date}')
      ORDER BY date_created DESC LIMIT 1;
    SQL

    appointment = ActiveRecord::Base.connection.select_one <<-SQL
      SELECT DATE(value_datetime) date
      FROM obs INNER JOIN encounter e ON e.encounter_id = obs.encounter_id
      WHERE concept_id = 5096 AND person_id = #{patient_id}
      AND encounter_type = 7 AND program_id = 1
      AND obs.voided  = 0 AND DATE(obs_datetime) = DATE('#{visit_date}')
      ORDER BY obs.date_created DESC LIMIT 1;
    SQL

    patient_available = begin
      patient_available['pa']
    rescue StandardError
      'N/A'
    end
    guardian_available = begin
      guardian_available['pa']
    rescue StandardError
      'N/A'
    end

    visit_type = if patient_available == 'YES' && guardian_available == 'YES'
                   'PG'
                 elsif patient_available == 'YES'
                   'P'
                 elsif patient_available == 'YES'
                   'G'
                 else
                   'N/A'
                 end

    {
      regimen: begin
        current_regimen['regimen']
      rescue StandardError
        nil
      end,
      outcome: current_outcome['outcome'],
      weight: begin
        current_weight['weight']
      rescue StandardError
        ''
      end,
      height: begin
        current_height['height']
      rescue StandardError
        ''
      end,
      appointment: begin
        appointment['date']
      rescue StandardError
        ''
      end,
      visit_type:,
      medication: medication_given
    }
  end

  def tpt_prescription_count(patient, _program, date)
    drug_concept_ids = ConceptName.where('name IN(?)',
                                         ['Isoniazid', 'Rifapentine', 'Isoniazid/Rifapentine']).map(&:concept_id)
    orders = Order.joins("INNER JOIN drug_order o ON o.order_id = orders.order_id
      INNER JOIN drug d ON d.drug_id = o.drug_inventory_id")\
                  .where("d.concept_id IN(?) AND orders.patient_id = ? AND DATE(start_date) < ?
      AND quantity > 0", drug_concept_ids, patient.id, date)\
                  .group('DATE(orders.start_date)').select('DATE(start_date)')
    { count: orders.length }
  end

  def find_patient_visits_dates_since_last_outcome(patient, program, date)
    outcome_date = patient_last_outcome_date(patient, program, date)
    encounters = visit_dates_ref(patient, program)
                          .where('encounter_datetime >= ?', outcome_date)
                          .order(encounter_datetime: :desc)
                          .group(:visit_date)
    encounters.present? ? encounters.map(&:visit_date) : []
  end

  def visit_dates_ref(patient, program)
    Encounter.select('DATE(encounter_datetime) AS visit_date')
             .where(patient_id: patient, program_id: program)
  end

  def patient_last_outcome_date(patient, program, date)
    obs = Observation.joins(:encounter)
                     .where(encounter: {
                          type: encounter_type('EXIT FROM CARE'),
                          patient_id: patient,
                          program_id: program
                        })
                        .where('DATE(obs_datetime) <= DATE(?)', date)
                        .where(concept: concept('Tuberculosis treatment end date'))
                        .order(obs_datetime: :desc).first
    obs.present? ? obs.value_datetime : '1970-01-01 00:00:00'
  end

  private

  def npid_identifier_types
    @npid_identifier_types = [patient_identifier_type('National id'),
                              patient_identifier_type('Old identification number')]
  end

  def use_dde_service?
    global_property('dde_enabled').property_value&.strip == 'true'
  rescue StandardError
    false
  end

  def dde_patient?(patient)
    identifier = patient.identifier('DDE person document id')&.identifier
    return false if identifier.nil?

    !identifier.blank?
  end

  def dde_service(program)
    DdeService.new(program:)
  end

  # Blesses patient with a v3 npid
  def assign_patient_v3_npid(patient)
    identifier_type = PatientIdentifierType.find_by(name: 'National id')
    identifier_type.next_identifier(patient:)
  end

  # Blesses patient with a v28 malawiNid
  def assign_patient_v28_malawiNid(patient, malawi_national_id)
    identifier_type = PatientIdentifierType.find_by(name: 'Malawi National ID')
    identifier_type.next_identifier_for_malawi_nid(patient:, MNID: malawi_national_id)
  end

  # Blesses patient with a DDE npid
  def assign_patient_dde_npid(patient, program)
    dde_service(program).create_patient(patient)
  end

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
      visit = trail[date] || { date:, sbp: nil, dbp: nil,
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
                  .where(patient:, concept: bp_drug_concepts)\
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

  def filing_number_service
    @filing_number_service ||= FilingNumberService.new
  end

  def patient_engine
    program = Program.find_by(name: 'TB PROGRAM')
    TbService::PatientsEngine.new program:
  end

  # Returns all of patient's identifiers of given identifier_type
  def patient_identifiers(patient, identifier_type)
    PatientIdentifier.where(patient:, type: identifier_type)
  end

  # Returns the next available patient identifier for assignment
  def next_available_npid(patient:, identifier_type:, program_id: nil)
    unless identifier_type.name.match?(/#{PatientIdentifierType::NPID_TYPE_NAME}/i)
      raise "Unknown identifier type: #{identifier_type.name}"
    end

    return identifier_type.next_identifier(patient:) unless use_dde_service?

    dde_patient_id_type = patient_identifier_type(PatientIdentifierType::DDE_ID_TYPE_NAME)
    dde_patient_id = patient_identifiers(patient, dde_patient_id_type).first&.identifier
    return dde_service(Program.find(program_id)).re_assign_npid(dde_patient_id) if dde_patient_id

    dde_service(Program.find(program_id)).create_patient(patient)
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

  def last_htn_drugs_received(patient, date)
    current_drugs = current_htn_drugs(patient, date)

    dispensed_concept_id = concept('AMOUNT DISPENSED')&.concept_id || -1
    last_dispensation = {}
    current_drugs.each_with_object({}) do |drug, hash|
      last_dispensation = Encounter.find_by_sql(
        [
          "SELECT SUM(obs.value_numeric) AS value_numeric, MAX(obs_datetime) AS obs_datetime, 0 AS remaining
           FROM encounter INNER JOIN obs ON obs.encounter_id = encounter.encounter_id AND encounter.voided = 0
            WHERE obs.value_drug = ? AND encounter.encounter_type = ? AND
                  encounter.patient_id = ? AND DATE(encounter.encounter_datetime) < ?
             AND obs.concept_id = ?
           GROUP BY DATE(obs_datetime)
           ORDER BY obs.obs_datetime DESC
           LIMIT 1",
          drug.id, encounter_type('DISPENSING').id, patient.id, date, dispensed_concept_id
        ]
      ).last

      remaining_last_time = Observation.where(
        [
          'concept_id = ? AND person_id = ? AND value_drug = ? AND DATE(obs_datetime) = ?',
          ConceptName.find_by_name('Amount of drug remaining at home').concept_id,
          patient.patient_id, drug.id, last_dispensation.obs_datetime.to_date
        ]
      ).last&.value_numeric || 0

      last_dispensation.remaining = ((last_dispensation.value_numeric.to_i + remaining_last_time.to_i)\
                                      - (date.to_date - last_dispensation.obs_datetime.to_date).to_i) # == days for a pill per day

      next unless last_dispensation

      hash[drug.name] = {
        value_numeric: last_dispensation.value_numeric,
        obs_datetime: last_dispensation.obs_datetime,
        remaining: last_dispensation.remaining
      }
    end
  end

  def update_remaining_drugs(patient, date, drug, pills)
    # TODO: Refactor this into smaller functions...
    # As is this code is pissing me off...
    encounter = find_htn_management_encounter(patient, date)
    order = find_htn_drug_order(encounter, drug)
    save_htn_hanging_pills(encounter, order, drug, pills)

    dispensed_concept_id = concept('AMOUNT DISPENSED').concept_id
    adherence_concept_id = concept('WHAT WAS THE PATIENTS ADHERENCE FOR THIS DRUG ORDER').concept_id

    last_dispensation = Encounter.find_by_sql(
      [
        "SELECT SUM(obs.value_numeric) AS value_numeric, MAX(obs_datetime) AS obs_datetime
         FROM encounter INNER JOIN obs ON obs.encounter_id = encounter.encounter_id AND encounter.voided = 0
         WHERE obs.value_drug = ? AND encounter.encounter_type = ? AND encounter.patient_id = ?
          AND DATE(encounter.encounter_datetime) < ? AND obs.concept_id = ?
         GROUP BY DATE(obs_datetime)
         ORDER BY obs.obs_datetime
         DESC LIMIT 1",
        drug.id, encounter_type('DISPENSING').id, patient.id, date, dispensed_concept_id
      ]
    ).last

    remaining_last_time = Observation.where(
      [
        'concept_id = ? AND person_id = ? AND value_drug = ? AND DATE(obs_datetime) = ?',
        ConceptName.find_by_name('Amount of drug remaining at home').concept_id,
        patient.id, drug.id, last_dispensation.obs_datetime.to_date
      ]
    ).last&.value_numeric || 0

    adherence = nil
    expected_amount_remaining = nil

    unless last_dispensation.blank?
      amount_given_last_time = last_dispensation.value_numeric.to_i
      expected_amount_remaining = ((amount_given_last_time + remaining_last_time.to_i)
                                   - (date - last_dispensation.obs_datetime.to_date)).to_i # == days for a pill per day
      amount_remaining = pills.to_i
      adherence = (100 * (amount_given_last_time - amount_remaining) / (amount_given_last_time - expected_amount_remaining)).round
    end

    obs = Observation.where(
      'person_id = ? AND concept_id = ? AND encounter_id = ? AND
       value_drug = ? AND DATE(obs_datetime) = ?',
      patient.id, adherence_concept_id, encounter.id, drug.id, date
    ).last

    unless adherence.blank?
      if obs.blank?
        Observation.create(
          obs_datetime: encounter.encounter_datetime,
          encounter_id: encounter.id,
          person_id: patient.id,
          location_id: Location.current.id,
          concept_id: adherence_concept_id,
          order_id: order.id,
          creator: User.current.id,
          value_numeric: adherence,
          value_modifier: '%',
          value_text: '',
          value_drug: drug.id
        )
      else
        obs.update_attributes(value_numeric: adherence)
      end
    end

    { adherence:, expected_amount_remaining: }
  end

  # Returns an HTN management encounter for the given patient on
  # a given day
  def find_htn_management_encounter(patient, date)
    type = encounter_type('HYPERTENSION MANAGEMENT')

    encounter = patient.encounters.where(type:)\
                       .where('encounter_datetime BETWEEN ? AND ?', *TimeUtils.day_bounds(date))\
                       .order(:encounter_datetime)
                       .last

    return encounter if encounter

    Encounter.create(encounter_datetime: date, type:,
                     creator: User.current.id, location_id: Location.current.id,
                     patient:)
  end

  def find_htn_drug_order(encounter, drug)
    Order.joins('INNER JOIN drug_order USING (order_id)')\
         .where('orders.patient_id = ? AND drug_order.drug_inventory_id = ?
                 AND orders.start_date < ?',
                encounter.patient_id, drug.id, encounter.encounter_datetime.to_date)\
         .select('orders.order_id')\
         .order('orders.start_date DESC')\
         .first\
  end

  def save_htn_hanging_pills(encounter, drug_order, drug, pills)
    concept_id = concept('Amount of drug remaining at home').concept_id

    obs = Observation.where(
      'person_id = ? AND concept_id = ? AND encounter_id = ? AND value_drug = ?',
      encounter.patient_id, concept_id, encounter.id, drug.id
    ).order(:obs_datetime).last

    if obs
      obs.update_attributes(value_numeric: pills)
      return obs
    end

    Observation.create(
      encounter:,
      obs_datetime: encounter.encounter_datetime,
      person_id: encounter.patient_id,
      location_id: Location.current.id,
      concept_id:,
      order_id: drug_order&.order_id,
      creator: User.current.id,
      value_numeric: pills,
      value_drug: drug.id
    )
  end

  def enrolled_on_program(patient, program_id, date = DateTime.now, create = false)
    # patient_id
    program = PatientProgram.where(['patient_id = ? AND program_id = ? AND date_enrolled <= ?',
                                    patient.id, program_id, date.strftime('%Y-%m-%d 23:59:59')]).last
    alive_concept_id = ConceptName.where(['name =?', 'Alive']).first.concept_id
    if program.blank? && create
      ActiveRecord::Base.transaction do
        program = PatientProgram.create({ program_id:, date_enrolled: date,
                                          patient_id: patient.id })
        alive_state = ProgramWorkflowState.where(['program_workflow_id = ? AND concept_id = ?',
                                                  ProgramWorkflow.where(['program_id = ?', program_id]).first.id, alive_concept_id]).first.id
        PatientState.create(patient_program_id: program.id, start_date: date, state: alive_state)
      end
    end

    program
  end

  def last_bp_readings(patient, date)
    sbp_concept = Concept.find_by_name('Systolic blood pressure').id
    dbp_concept = Concept.find_by_name('Diastolic blood pressure').id
    patient_id = patient.id

    latest_date = begin
      Observation.find_by_sql("
      SELECT MAX(obs_datetime) AS date FROM obs
      WHERE person_id = #{patient_id}
        AND voided = 0
        AND concept_id IN (#{sbp_concept}, #{dbp_concept})
        AND obs_datetime <= '#{date.to_date.strftime('%Y-%m-%d 23:59:59')}'
      ").last.date.to_date
    rescue StandardError
      nil
    end

    return nil if latest_date.blank?

    sbp = begin
      Observation.find_by_sql("
        SELECT * FROM obs
        WHERE person_id = #{patient_id}
          AND voided = 0
          AND concept_id = #{sbp_concept}
          AND obs_datetime BETWEEN '#{latest_date.to_date.strftime('%Y-%m-%d 00:00:00')}' AND '#{latest_date.to_date.strftime('%Y-%m-%d 23:59:59')}'
      ").last.value_numeric
    rescue StandardError
      nil
    end

    dbp = begin
      Observation.find_by_sql("
        SELECT * FROM obs
        WHERE person_id = #{patient_id}
          AND voided = 0
          AND concept_id = #{dbp_concept}
          AND obs_datetime BETWEEN '#{latest_date.to_date.strftime('%Y-%m-%d 00:00:00')}' AND '#{latest_date.to_date.strftime('%Y-%m-%d 23:59:59')}'
      ").last.value_numeric
    rescue StandardError
      nil
    end

    { patient_id:, max_date: latest_date, sbp:, dbp: }
  end
end
