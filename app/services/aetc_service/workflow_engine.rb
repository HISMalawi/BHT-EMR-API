# frozen_string_literal: true

require 'set'

module AetcService
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
    VITALS = 'VITALS'
    PRESENTING_COMPLAINTS = 'PRESENTING COMPLAINTS'
    OUTPATIENT_DIAGNOSIS = 'OUTPATIENT DIAGNOSIS'
    PRESCRIPTION = 'PRESCRIPTION'
    DISPENSING = 'DISPENSING'
    TREATMENT = 'TREATMENT'


    ENCOUNTER_SM = {
      INITIAL_STATE => PATIENT_REGISTRATION,
      PATIENT_REGISTRATION => SOCIAL_HISTORY,
      SOCIAL_HISTORY => VITALS,
      VITALS => END_STATE
    }.freeze

    STATE_CONDITIONS = {
      PATIENT_REGISTRATION => %i[patient_not_registered_today?],
      SOCIAL_HISTORY => %i[social_history_not_collected?],
      VITALS => %i[patient_does_not_have_height_and_weight?]
    }.freeze

    ACTIVITY_MAP = {
      'patient registration' => PATIENT_REGISTRATION,
      'social history' => SOCIAL_HISTORY,
      'vitals' => VITALS,
      'presenting complaints' => PRESENTING_COMPLAINTS,
      'outpatient diagnosis' => OUTPATIENT_DIAGNOSIS,
      'prescription' => PRESCRIPTION,
      'dispensing' => DISPENSING
    }.freeze

    def load_user_activities
      activities = user_property('AETC_activities')&.property_value || 'Patient registration,Social history,Vitals'

      Set.new(activities.split(',').map do |activity|
        activity_name = activity.strip.downcase
        if ACTIVITY_MAP.key?(activity_name)
          ACTIVITY_MAP[activity_name]
        else
          Rails.logger.warn "Invalid AETC activity in user properties: #{activity}"
          nil
        end
      end.compact)
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
      return false if encounter_exists?(encounter_type(state)) || !aetc_activity_enabled?(state)

      (STATE_CONDITIONS[state] || []).reduce(true) do |status, condition|
        status && method(condition).call
      end
    end

    def aetc_activity_enabled?(state)
      @activities.include?(state)
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
        'encounter_type.name = ? AND encounter.patient_id = ? AND encounter.program_id = ?',
        SOCIAL_HISTORY, @patient.patient_id, @program.id
      )

      encounter.blank?
    end

    def patient_does_not_have_height_and_weight?
      return true if patient_has_no_weight_today?

      return true if patient_has_no_height?

      patient_has_no_height_today?
    end

    def patient_has_no_weight_today?
      concept_id = ConceptName.find_by_name('Weight').concept_id
      !Observation.where(concept_id: concept_id, person_id: @patient.id)\
                  .where('obs_datetime BETWEEN ? AND ?', *TimeUtils.day_bounds(@date))\
                  .exists?
    end

    def patient_has_no_height?
      concept_id = ConceptName.find_by_name('Height (cm)').concept_id
      !Observation.where(concept_id: concept_id, person_id: @patient.id)\
                  .where('obs_datetime < ?', TimeUtils.day_bounds(@date)[1])\
                  .exists?
    end

    def patient_has_no_height_today?
      concept_id = ConceptName.find_by_name('Height (cm)').concept_id
      !Observation.where(concept_id: concept_id, person_id: @patient.id)\
                  .where('obs_datetime BETWEEN ? AND ?', *TimeUtils.day_bounds(@date))\
                  .exists?
    end
  end
end
