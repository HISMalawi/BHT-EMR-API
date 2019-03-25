# frozen_string_literal: true

require 'set'

module OPDService
  class WorkflowEngine
    include ModelUtils

    def initialize(program:, patient:, date:)
      @patient = patient
      @program = program
      @date = date
      @activities = load_user_activities
    end

    # Retrieves the next encounter for bound patient
    def next_encounter
      state = INITIAL_STATE
      loop do
        state = next_state state
        break if state == END_STATE

        LOGGER.debug "Loading encounter type: #{state}"
        encounter_type = EncounterType.find_by(name: state)

        return encounter_type if valid_state?(state)
      end

      nil
    end

    private

    LOGGER = Rails.logger

    # Encounter types
    INITIAL_STATE = 0 # Start terminal for encounters graph
    END_STATE = 1 # End terminal for encounters graph
    SOCIAL_HISTORY = 'SOCIAL HISTORY'
    PATIENT_REGISTRATION = 'PATIENT REGISTRATION'
=begin
    # Encounters graph
    ENCOUNTER_SM = {
      INITIAL_STATE => PATIENT_REGISTRATION,
      PATIENT_REGISTRATION => SOCIAL_HISTORY,
      SOCIAL_HISTORY => END_STATE
    }.freeze

    STATE_CONDITIONS = {
      PATIENT_REGISTRATION => %i[patient_not_registered_today?],
      SOCIAL_HISTORY => %i[social_history_not_collected?]
    }.freeze
=end
    # Encounters graph
    ENCOUNTER_SM = {
      INITIAL_STATE => PATIENT_REGISTRATION
    }.freeze

    STATE_CONDITIONS = {
      PATIENT_REGISTRATION => %i[patient_not_registered_today?]
    }.freeze

    def load_user_activities
      #activities = ['Patient registration,Social history']
      activities = ['Patient registration']
      encounters = (activities&.split(',') || []).collect do |activity|
        # Re-map activities to encounters
        puts activity
        case activity
        when /Patient registration/i
          PATIENT_REGISTRATION
        when /Social history/i
          SOCIAL_HISTORY
        else
          Rails.logger.warn "Invalid OPD activity in user properties: #{activity}"
        end
      end

    end

    def next_state(current_state)
      ENCOUNTER_SM[current_state]
    end

    # Check if a relevant encounter of given type exists for given patient.
    #
    # NOTE: By `relevant` above we mean encounters that matter in deciding
    # what encounter the patient should go for in this present time.
    def encounter_exists?(type)
      Encounter.where(type: type, patient: @patient)\
               .where('encounter_datetime BETWEEN ? AND ?', *TimeUtils.day_bounds(@date))\
               .exists?
    end

    def valid_state?(state)
      return false if encounter_exists?(encounter_type(state))

      (STATE_CONDITIONS[state] || []).reduce(true) do |status, condition|
        status && method(condition).call
      end
    end

    # Checks if patient has checked in today
    #
    def patient_not_registered_today?
      encounter_type = EncounterType.find_by name: PATIENT_REGISTRATION
      encounter = Encounter.joins(:type).where(
        'patient_id = ? AND encounter_type = ? AND DATE(encounter_datetime) = DATE(?)',
        @patient.patient_id, encounter_type.encounter_type_id, @date
      ).order(encounter_datetime: :desc).first

      encounter.blank? 
    end

    # Check if patient is not registered
    def social_history_not_collected?
      encounter = Encounter.joins(:type).where(
        'encounter_type.name = ? AND encounter.patient_id = ?',
        SOCIAL_HISTORY, @patient.patient_id)

      encounter.blank?
    end

  end
end
