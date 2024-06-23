# frozen_string_literal: true

module OpdService
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
    VITALS = 'VITALS'
    PRESENTING_COMPLAINTS = 'PRESENTING COMPLAINTS'
    LAB_RESULTS = 'LAB RESULTS'
    LAB_ORDERS = 'LAB ORDERS'
    OUTPATIENT_DIAGNOSIS = 'OUTPATIENT DIAGNOSIS'
    PRESCRIPTION = 'PRESCRIPTION'
    PATIENT_OUTCOME = 'PATIENT OUTCOME'
    TREATMENT = 'TREATMENT'
    #     # Encounters graph
    #     ENCOUNTER_SM = {
    #       INITIAL_STATE => PATIENT_REGISTRATION,
    #       PATIENT_REGISTRATION => SOCIAL_HISTORY,
    #       SOCIAL_HISTORY => END_STATE
    #     }.freeze
    #
    #     STATE_CONDITIONS = {
    #       PATIENT_REGISTRATION => %i[patient_not_registered_today?],
    #       SOCIAL_HISTORY => %i[social_history_not_collected?]
    #     }.freeze
    # Encounters graph
    ENCOUNTER_SM = {
      INITIAL_STATE => VITALS,
      VITALS  => PRESENTING_COMPLAINTS,
      PRESENTING_COMPLAINTS => LAB_RESULTS,
      LAB_RESULTS => OUTPATIENT_DIAGNOSIS,
      OUTPATIENT_DIAGNOSIS => PRESCRIPTION,
      PRESCRIPTION => PATIENT_OUTCOME,
      PATIENT_OUTCOME => END_STATE
    }.freeze

    STATE_CONDITIONS = {
      VITALS => %i[patient_does_not_have_height_and_weight?],
      PRESENTING_COMPLAINTS => %i[patient_does_not_have_complaints?],
      LAB_RESULTS => %i[patient_does_not_have_lab_results?],
      OUTPATIENT_DIAGNOSIS => %i[patient_does_not_have_diagnosis?],
      PRESCRIPTION => %i[patient_does_not_have_prescription?],
      PATIENT_OUTCOME => %i[patient_does_not_have_outcomes?]
    }.freeze

    def load_user_activities
      activities = "Clinical Assessment,Investigations,Diagnosis,Treatment,Outcome"     
      # activities = user_property('OPD_activities')&.property_value
      # activities = 'Patient registration,Social history,Vitals' if activities.blank?

      LOGGER.debug "Re-map activities to encounters: #{activities}"
      encounters = (activities&.split(',') || []).collect do |activity|
        # Re-map activities to encounters
        puts activity
        case activity
        when /Vitals/i
          VITALS
        when /Clinical Assessment/i
          PRESENTING_COMPLAINTS
        when /Investigations/i
          LAB_RESULTS
        when /Diagnosis/i
          OUTPATIENT_DIAGNOSIS
        when /Treatment/i
          PRESCRIPTION
        when /Outcome/i
          PATIENT_OUTCOME
        else
          Rails.logger.warn "Invalid OPD activity in user properties: #{activity}"
        end
      end
      Set.new(encounters)
    end

    def next_state(current_state)
      ENCOUNTER_SM[current_state]
    end

    # Check if a relevant encounter of given type exists for given patient.
    #
    # NOTE: By `relevant` above we mean encounters that matter in deciding
    # what encounter the patient should go for in this present time.
    def encounter_exists?(type)
      Encounter.where(type:, patient: @patient)\
               .where('encounter_datetime BETWEEN ? AND ?', *TimeUtils.day_bounds(@date))\
               .exists?
    end

    def valid_state?(state)
      return false if encounter_exists?(encounter_type(state)) || !opd_activity_enabled?(state)

      (STATE_CONDITIONS[state] || []).reduce(true) do |status, condition|
        status && method(condition).call
      end
    end

    def opd_activity_enabled?(state)
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

    # Checks if patient has complaints in today
    #
    def patient_does_not_have_complaints?
      encounter_type = EncounterType.find_by name: PRESENTING_COMPLAINTS
      encounter = Encounter.joins(:type).where(
        'patient_id = ? AND encounter_type = ? AND DATE(encounter_datetime) = DATE(?)',
        @patient.patient_id, encounter_type.encounter_type_id, @date
      ).order(encounter_datetime: :desc).first

      encounter.blank?
    end

    # Checks if patient has lab  in today
    #
    def patient_does_not_have_lab_results?
        encounter_type = EncounterType.find_by name: LAB_RESULTS
        encounter = Encounter.joins(:type).where(
          'patient_id = ? AND encounter_type = ? AND DATE(encounter_datetime) = DATE(?)',
          @patient.patient_id, encounter_type.encounter_type_id, @date
        ).order(encounter_datetime: :desc).first
        Rails.logger.warn "encounter.blank? activity in user properties: #{encounter.blank?}"
        encounter.blank?
    end

    # Checks if patient has lab  in today
    #
    def patient_does_not_have_lab_order?
      encounter_type = EncounterType.find_by name: LAB_ORDERS
      encounter = Encounter.joins(:type).where(
        'patient_id = ? AND encounter_type = ? AND DATE(encounter_datetime) = DATE(?)',
        @patient.patient_id, encounter_type.encounter_type_id, @date
      ).order(encounter_datetime: :desc).first

      encounter.blank?
    end

    # Checks if patient has diagnosis today
    #
    def patient_does_not_have_diagnosis?
      encounter_type = EncounterType.find_by name: OUTPATIENT_DIAGNOSIS
      encounter = Encounter.joins(:type).where(
        'patient_id = ? AND encounter_type = ? AND DATE(encounter_datetime) = DATE(?)',
        @patient.patient_id, encounter_type.encounter_type_id, @date
      ).order(encounter_datetime: :desc).first

      encounter.blank?
    end

    # Checks if patient has prescription today
    #
    def patient_does_not_have_prescription?
      encounter_type = EncounterType.find_by name: TREATMENT
      encounter = Encounter.joins(:type).where(
        'patient_id = ? AND encounter_type = ? AND DATE(encounter_datetime) = DATE(?)',
        @patient.patient_id, encounter_type.encounter_type_id, @date
      ).order(encounter_datetime: :desc).first

      encounter.blank?
    end

    # Checks if patient has prescription today
    #
    def patient_does_not_have_outcomes?
      encounter_type = EncounterType.find_by name: PATIENT_OUTCOME
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
        SOCIAL_HISTORY, @patient.patient_id
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
      !Observation.where(concept_id:, person_id: @patient.id)\
                  .where('obs_datetime BETWEEN ? AND ?', *TimeUtils.day_bounds(@date))\
                  .exists?
    end

    def patient_has_no_height?
      concept_id = ConceptName.find_by_name('Height (cm)').concept_id
      !Observation.where(concept_id:, person_id: @patient.id)\
                  .where('obs_datetime < ?', TimeUtils.day_bounds(@date)[1])\
                  .exists?
    end

    def patient_has_no_height_today?
      concept_id = ConceptName.find_by_name('Height (cm)').concept_id
      !Observation.where(concept_id:, person_id: @patient.id)\
                  .where('obs_datetime BETWEEN ? AND ?', *TimeUtils.day_bounds(@date))\
                  .exists?
    end
  end
end
