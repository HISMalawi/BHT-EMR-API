# frozen_string_literal: true

class VmmcService::WorkflowEngine
  include ModelUtils

  attr_reader :program, :patient, :date

  def initialize(program:, patient:, date:)
    @program = program
    @patient = patient
    @date = date
    @user_activities = ""
    @activities = load_user_activities
  end

  def next_encounter
    # 'N/A'
    state = INITIAL_STATE
    loop do
    	state = next_state state
    	break if state == END_STATE

    	LOGGER.debug "Loading encounter type: #{state}"
    	encounter_type = EncounterType.find_by(name: state)

    	return encounter_type if valid_state?(state)
  	end
  end

  def valid_state?(state)
    # if state == POST_OP_REVIEW
    #   raise encounter_exists?(encounter_type(state)).inspect
    # end

    if encounter_exists?(encounter_type(state)) || !@activities.include?(state)
      return false
    end

    (STATE_CONDITIONS[state] || []).reduce(true) do |status, condition|
      status && method(condition).call
    end
  end

  private

  LOGGER = Rails.logger

  # Encounter types
  INITIAL_STATE = 0 # Start terminal for encounters graph
  END_STATE = 1 # End terminal for encounters graph
  REGISTRATION_CONSENT = 'REGISTRATION CONSENT'
  HIV_STATUS = 'UPDATE HIV STATUS'
  VITALS = 'VITALS'
  MEDICAL_HISTORY = 'MEDICAL HISTORY'  
  GENITAL_EXAMINATION = 'GENITAL EXAMINATION'
  SUMMARY_ASSESSMENT = 'SUMMARY ASSESSMENT'
  CIRCUMCISION = 'CIRCUMCISION'
  POST_OP_REVIEW = 'POST-OP REVIEW'
  TREATMENT = 'TREATMENT'
  APPOINTMENT = 'APPOINTMENT'
  FOLLOW_UP = 'FOLLOW UP'

  # Encounters graph
  ENCOUNTER_SM = {
    INITIAL_STATE => REGISTRATION_CONSENT,
    REGISTRATION_CONSENT => HIV_STATUS,
    HIV_STATUS => VITALS,
    VITALS => MEDICAL_HISTORY,
    MEDICAL_HISTORY => GENITAL_EXAMINATION,
    GENITAL_EXAMINATION => SUMMARY_ASSESSMENT,
    SUMMARY_ASSESSMENT => CIRCUMCISION,
    CIRCUMCISION => POST_OP_REVIEW,
    POST_OP_REVIEW => TREATMENT,
    TREATMENT => APPOINTMENT,
    APPOINTMENT => FOLLOW_UP,
    FOLLOW_UP => END_STATE
  }.freeze

  STATE_CONDITIONS = {
    REGISTRATION_CONSENT => %i[patient_has_never_had_post_op_review?],
    VITALS => %i[patient_gives_consent?],
    MEDICAL_HISTORY => %i[patient_gives_consent?],
    HIV_STATUS => %i[patient_gives_consent?],
    GENITAL_EXAMINATION => %i[patient_gives_consent?],
    SUMMARY_ASSESSMENT => %i[patient_gives_consent?],
    CIRCUMCISION => %i[patient_gives_consent? continue_to_circumcision?],
    POST_OP_REVIEW => %i[patient_gives_consent? continue_to_circumcision?],
    TREATMENT => %i[patient_gives_consent? meds_given? continue_to_circumcision?],
    APPOINTMENT => %i[patient_gives_consent? patient_not_ready_for_discharge?],
    FOLLOW_UP => %i[patient_had_post_op_review?]
  }.freeze

  def load_user_activities
    activities = user_property('Activities')&.property_value
    encounters = (activities&.split(',') || []).collect do |activity|
      # Re-map activities to encounters
      case activity
      when /Registration Consent/i
        REGISTRATION_CONSENT
      when /medical history/i
        MEDICAL_HISTORY
      when /vitals/i
        VITALS
      when /update hiv status/i
        HIV_STATUS
      when /genital examination/i
        GENITAL_EXAMINATION
      when /summary assessment/i
        SUMMARY_ASSESSMENT
      when /circumcision/i
        CIRCUMCISION
      when /post-op review/i
        POST_OP_REVIEW
      when /treatment/i
        TREATMENT
      when /Appointment/i
        APPOINTMENT
      when /follow up/i
        FOLLOW_UP
      else
        Rails.logger.warn "Invalid VMMC activity in user properties: #{activity}"
      end
    end

    encounters
  end

  def next_state(current_state)
    ENCOUNTER_SM[current_state]
  end

  def encounter_exists?(type)
    Encounter.where(type: type, patient: @patient, program_id: vmmc_program.program_id)\
             .where('encounter_datetime <= ?', @date.strftime("%Y-%m-%d 23:59:59"))\
             .exists?
  end

  def vmmc_program
    @vmmc_program ||= Program.find_by_name('VMMC Program')
  end

  def yes_concept
    @yes_concept ||= ConceptName.find_by_name('Yes')
  end

  def patient_gives_consent?
    return @patient_gives_consent unless @patient_gives_consent.nil?

    return false if patient_had_post_op_review?

    consent_confirmation_concept_id = ConceptName.find_by_name('Consent Confirmation').concept_id

    @patient_gives_consent = Observation.joins(:encounter)\
                                        .where(person_id: @patient.id,
                                               concept_id: consent_confirmation_concept_id,
                                               value_coded: yes_concept.concept_id,
                                               encounter: { program_id: vmmc_program.id })\
                                        .where('encounter_datetime between ? AND ?', *TimeUtils.day_bounds(date))\
                                        .exists?
  end

  def continue_to_circumcision?
    return false unless patient_suitable_for_circumcision?

    continue_to_circumcision_concept_id = ConceptName.find_by_name('Continue to circumcision?').concept_id

     Observation.joins(:encounter)\
               .where(person_id: @patient.id,
                      concept_id: continue_to_circumcision_concept_id,
                      value_coded: yes_concept.concept_id)\
               .where('encounter_datetime between ? AND ?', *TimeUtils.day_bounds(date))\
               .merge(Encounter.where(program_id: vmmc_program.program_id))
               .exists?
  end

  def vmmc_registration_encounter_not_collected?
    encounter = Encounter.joins(:type).where(
      'encounter_type.name = ? AND encounter.patient_id = ?',
      REGISTRATION, @patient.patient_id)

    encounter.blank?
  end

  def post_op_review_encounter_not_collected?
    encounter = Encounter.joins(:type).where(
      'encounter_type.name = ? AND encounter.patient_id = ?',
      POST_OP_REVIEW, @patient.patient_id)

    encounter.blank?
  end

  def summary_assessment_encounter_not_collected?
    encounter = Encounter.joins(:type).where(
      'encounter_type.name = ? AND encounter.patient_id = ?',
      SUMMARY_ASSESSMENT, @patient.patient_id)

    encounter.blank?
  end

  def meds_given?
    meds_given_concept_id = ConceptName.find_by_name('Meds given?').concept_id
    yes_concept_id = ConceptName.find_by_name('Yes').concept_id

    Observation.joins(:encounter)\
               .where(concept_id: meds_given_concept_id,
                      value_coded: yes_concept_id,
                      person_id: patient.id)\
               .merge(Encounter.where(program: vmmc_program))
               .exists?
  end

  def patient_not_ready_for_discharge?
    ready_for_discharge_concept_id = ConceptName.find_by_name('Ready for discharge?').concept_id
    yes_concept_id = ConceptName.find_by_name('Yes').concept_id

    !Observation.joins(:encounter)\
                .where(concept_id: ready_for_discharge_concept_id,
                       value_coded: yes_concept_id,
                       person_id: patient.patient_id)\
                .merge(Encounter.where(program: vmmc_program))
                .exists?
  end

    def medical_history_not_collected?

      medical_history_enc = EncounterType.find_by name: MEDICAL_HISTORY

      med_history = Encounter.where("encounter_type = ?
          AND patient_id = ? AND DATE(encounter_datetime) >= DATE(?)",
          medical_history_enc.id, @patient.patient_id, @date)
        .order(encounter_datetime: :desc).first.blank?

      med_history
    end

  def patient_tested_for_hiv?
          hiv_status_enc = EncounterType.find_by name: STATUS

      hiv_status = Encounter.where("encounter_type = ?
          AND patient_id = ? AND DATE(encounter_datetime) >= DATE(?)",
          hiv_status_enc.id, @patient.patient_id, @date)
        .order(encounter_datetime: :desc).first.blank?

      hiv_status

  end

  def patient_has_never_had_post_op_review?
    @patient_has_never_had_post_op_review ||= !patient_had_post_op_review?
  end

  def patient_had_post_op_review?
    return @patient_had_post_op_review unless @patient_had_post_op_review.nil?

    encounter = Encounter.where(type: encounter_type(POST_OP_REVIEW),
                                patient: patient,
                                program: program.id)\
                         .order(:encounter_datetime)\
                         .last

    return @patient_had_post_op_review = false unless encounter

    # Only valid if encounter was not done today
    @patient_had_post_op_review = encounter.encounter_datetime.to_date != date.to_date
  end

  # Checks if patient has passed summary assessment.
  #
  # Pre-condition for all encounters after summary assessment but `APPOINTMENT`.
  def patient_suitable_for_circumcision?
    # Memoize as this may be called a number of times within one request.
    # It is a pre-condition to a number of encounters.
    return @patient_suitable_for_circumcision unless @patient_suitable_for_circumcision.nil?

    @patient_suitable_for_circumcision = begin
      Observation.joins(:encounter)\
                 .where(concept: concept('Suitable for circumcision'),
                        value_coded: concept('Yes').concept_id)\
                 .where('DATE(obs_datetime) = ?', date.to_date)\
                 .merge(Encounter.where(patient: patient, program: program))\
                 .exists?
    end
  end
end
