module ANCService
  class WorkflowEngine
    include ModelUtils

    def initialize(program:, patient:, date:)
      @patient = patient
      @program = program
      @date = date
      @user_activities = ""
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
    VITALS = 'VITALS'
    DISPENSING = 'DISPENSING'
    ANC_VISIT_TYPE = 'ANC VISIT TYPE'
    OBSTETRIC_HISTORY = 'OBSTETRIC HISTORY'
    MEDICAL_HISTORY = 'MEDICAL HISTORY'
    SURGICAL_HISTORY = 'SURGICAL HISTORY'
    LAB_RESULTS = 'LAB RESULTS'
    CURRENT_PREGNANCY = 'CURRENT PREGNANCY' # ASSESMENT[sic] - It's how its named in the db
    OBSERVATIONS = 'OBSERVATIONS'
    APPOINTMENT = 'APPOINTMENT'
    TREATMENT = 'TREATMENT'

    # Encounters graph
    ENCOUNTER_SM = {
      INITIAL_STATE => DISPENSING,
      DISPENSING => VITALS,
      VITALS => ANC_VISIT_TYPE,
      ANC_VISIT_TYPE => OBSTETRIC_HISTORY,
      OBSTETRIC_HISTORY => MEDICAL_HISTORY,
      MEDICAL_HISTORY => SURGICAL_HISTORY,
      SURGICAL_HISTORY => LAB_RESULTS,
      LAB_RESULTS => CURRENT_PREGNANCY,
      CURRENT_PREGNANCY => OBSERVATIONS,
      OBSERVATIONS => APPOINTMENT,
      APPOINTMENT => TREATMENT,
      TREATMENT => END_STATE
    }.freeze

    STATE_CONDITIONS = {
      DISPENSING => %i[patient_has_not_been_given_ttv?]
=begin
      HIV_STAGING => %i[patient_not_already_staged?
                        patient_has_not_completed_fast_track_visit?],
      HIV_CLINIC_CONSULTATION => %i[patient_not_on_fast_track?
                                    patient_has_not_completed_fast_track_visit?],
      ART_ADHERENCE => %i[patient_received_art?
                          patient_has_not_completed_fast_track_visit?],
      TREATMENT => %i[patient_should_get_treatment?
                      patient_has_not_completed_fast_track_visit?],
      FAST_TRACK => %i[patient_got_treatment?
                       patient_not_on_fast_track?
                       assess_for_fast_track?
                       patient_has_not_completed_fast_track_visit?],
      DISPENSING => %i[patient_got_treatment?
                       patient_has_not_completed_fast_track_visit?],
      APPOINTMENT => %i[patient_got_treatment?
                        dispensing_complete?]
=end
    }.freeze

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

    # Check if patient is not been given ttv
    def patient_has_not_been_given_ttv?
      dispensing_encounter_exist = Encounter.joins(:type).where(
        'encounter_type.name = ? AND encounter.patient_id = ?',
        DISPENSING,
        @patient.patient_id
      ).exists?

      !dispensing_encounter_exist
    end

    # Checks if patient has checked in today
    #
    # Pre-condition for VITALS encounter
    def patient_checked_in?
      encounter_type = EncounterType.find_by name: HIV_RECEPTION
      encounter = Encounter.where(
        'patient_id = ? AND encounter_type = ? AND DATE(encounter_datetime) = DATE(?)',
        @patient.patient_id, encounter_type.encounter_type_id, @date
      ).order(encounter_datetime: :desc).first
      raise "Can't check if patient checked in due to missing HIV_RECEPTION" if encounter.nil?

      patient_present_concept = concept PATIENT_PRESENT
      yes_concept = concept 'YES'
      encounter.observations.exists? concept_id: patient_present_concept.concept_id,
                                     value_coded: yes_concept.concept_id
    end

  end
end
