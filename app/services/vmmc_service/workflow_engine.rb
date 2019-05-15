# frozen_string_literal: true

class VMMCService::WorkflowEngine
  attr_reader :program, :patient

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

    	return encounter_type if valid_state(state)    		
    	end
  	end
  end

    def valid_state?(state)
       if !@activities.include?(state)
        return false
      end

      if is_not_a_subsequent_visit? || !ONE_TIME_ENCOUNTERS.include?(state)
        return false if encounter_exists?(encounter_type(state))
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
    REGISTRATION = 'REGISTRATION'
    VITALS = 'VITALS'
    MEDICAL_HISTORY = 'MEDICAL HISTORY'
    HIV_STATUS = 'HIV_STATUS'
    GENITAL_EXAMINATION = 'GENITAL_EXAMINATION'
    SUMMARY_ASSESSMENT = 'SUMMARY_ASSESSMENT'
    CIRCUMCISION = 'CIRCUMCISION'
    POST_OP_REVIEW = 'POST_OP_REVIEW'
    FOLLOW_UP = 'FOLLOW_UP'

    ONE_TIME_ENCOUNTERS = [
      REGISTRATION,VITALS,HIV_STATUS,MEDICAL_HISTORY,
      GENITAL_EXAMINATION,SUMMARY_ASSESSMENT,
      CIRCUMCISION
    ]

    # Encounters graph
    ENCOUNTER_SM = {
      INITIAL_STATE => REGISTRATION,
      REGISTRATION => VITALS,
      VITALS => MEDICAL_HISTORY,
      MEDICAL_HISTORY => HIV_STATUS,
      HIV_STATUS => GENITAL_EXAMINATION,
      GENITAL_EXAMINATION => SUMMARY_ASSESSMENT,
      SUMMARY_ASSESSMENT => CIRCUMCISION,
      CIRCUMCISION => POST_OP_REVIEW,
      POST_OP_REVIEW => FOLLOW_UP,
      FOLLOW_UP => END_STATE
    }.freeze

    STATE_CONDITIONS = {
      REGISTRATION => %i[patient_gives_consent?],
      MEDICAL_HISTORY => %i[is_not_a_subsequent_visit?
                        medical_history_not_collected?],
      HIV_STATUS => %i[is_not_a_subsequent_visit?
      					patient_tested_for_hiv?],
      GENITAL_EXAMINATION => %i[is_not_a_subsequent_visit?
                        genital_examination_not_done?],
      SUMMARY_ASSESSMENT => %i[is_not_a_subsequent_visit?
                          genital_examination_done?],
      CIRCUMCISION => %i[is_not_a_subsequent_visit?
                      circumcision_not_done?],
      POST_OP_REVIEW => %i[patient_has_circumcision_encounter?],
      FOLLOW_UP => %i[patient_has_post_op_review_encounter?],

    }.freeze

    def load_user_activities
      activities = user_property('Activities')&.property_value
      encounters = (activities&.split(',') || []).collect do |activity|
        # Re-map activities to encounters
        puts activity
        case activity
        when /vitals/i
          VITALS
        when /registration/i
          REGISTRATION
        when /medical history/i
          MEDICAL_HISTORY
        when /hiv status/i
          HIV_STATUS
        when /genital examination/i
          GENITAL_EXAMINATION
        when /summary assessment/i
          SUMMARY_ASSESSMENT
        when /circumcision/i
          CIRCUMCISION
        when /post op review/i
          POST_OP_REVIEW
        when /followup/i
          FOLLOW_UP
        when /vitals/i
          VITALS
        else
          Rails.logger.warn "Invalid VMMC activity in user properties: #{activity}"
        end
    end

    def next_state(current_state)
      ENCOUNTER_SM[current_state]
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
