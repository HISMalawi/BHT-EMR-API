# frozen_string_literal: true

require 'set'

module TBService
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

    # Encounter types TB_INITIAL, TB_FOLLOWUP, TB RECEPTION, TB REGISTRATION
    INITIAL_STATE = 0 # Start terminal for encounters graph
    END_STATE = 1 # End terminal for encounters graph
    TB_SCREENING = 'TB SCREENING' #This should be added
    TB_INITIAL = 'TB_INITIAL'
    TB_REGISTRATION  = 'TB REGISTRATION'
    TB_RECEPTION = 'TB RECEPTION'
		VITALS = 'VITALS'
    LAB_ORDERS = 'LAB ORDERS'
    TREATMENT = 'TREATMENT'
    DISPENSING = 'DISPENSING'
   
    # Encounters graph
    ENCOUNTER_SM = {
      INITIAL_STATE => TB_INITIAL,
      TB_INITIAL => LAB_ORDERS,
      LAB_ORDERS => VITALS,
      VITALS => TREATMENT,
      TREATMENT => DISPENSING,
      DISPENSING => END_STATE
    }.freeze

    #For TB Initial == patient_not_visiting? patient_not_registered?
    #for TB Registration == patient_not_visiting?
    STATE_CONDITIONS = {
      TB_INITIAL => %i[tb_suspect_not_enrolled? 
                        patient_labs_not_ordered?],
      LAB_ORDERS => %i[patient_labs_not_ordered?],
      TREATMENT => %i[patient_should_get_treatment?],
      DISPENSING => %i[patient_got_treatment?]
    }.freeze   

    # Concepts
    PATIENT_PRESENT = 'Patient present'

    def load_user_activities
      activities = user_property('Activities')&.property_value
      encounters = (activities&.split(',') || []).collect do |activity|
        # Re-map activities to encounters
        puts activity
      case activity
        when /TB initial/i
          TB_INITIAL
        when /TB lab orders/i
          LAB_ORDERS
        when /Vitals/i
          VITALS
        when /Treatment/i
          TREATMENT
        when /Dispensing/i
          DISPENSING
        else
          Rails.logger.warn "Invalid TB activity in user properties: #{activity}"
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
    # Pre-condition for VITALS encounter
    def patient_checked_in?
      encounter_type = EncounterType.find_by name: TB_RECEPTION
      encounter = Encounter.where(
        'patient_id = ? AND encounter_type = ? AND DATE(encounter_datetime) = DATE(?)',
        @patient.patient_id, encounter_type.encounter_type_id, @date
      ).order(encounter_datetime: :desc).first
      raise "Can't check if patient checked in due to missing TB_RECEPTION" if encounter.nil?

      patient_present_concept = concept PATIENT_PRESENT
      yes_concept = concept 'YES'
      encounter.observations.exists? concept_id: patient_present_concept.concept_id,
                                     value_coded: yes_concept.concept_id
    end

    # Check if patient is not registered TB_CLINIC_REGISTRATION
    def patient_not_registered?
      is_registered = Encounter.joins(:type).where(
        'encounter_type.name = ? AND encounter.patient_id = ?',
        TB_REGISTRATION,
        @patient.patient_id
      ).exists?

      !is_registered
    end

    # Check if patient is not a visiting patient TB_CLINIC_REGISTRATION
    def patient_not_visiting?
      patient_type_concept = concept('Type of patient')
      raise '"Type of patient" concept not found' unless patient_type_concept

      visiting_patient_concept = concept('External consultation')
      raise '"External consultation" concept not found' unless visiting_patient_concept

      is_visiting_patient = Observation.where(
        concept: patient_type_concept,
        person: @patient.person,
        value_coded: visiting_patient_concept.concept_id
      ).exists?

      !is_visiting_patient
    end
    
    # Check if patient LAB_ORDERS has been made
    #newly added
    def tb_suspect_not_enrolled?
      is_suspect_enrolled = Encounter.joins(:type).where(
        'encounter_type.name = ? AND encounter.patient_id = ?',
        TB_INITIAL,
        @patient.patient_id
      ).exists?

      !is_suspect_enrolled
    end

    def patient_labs_not_ordered? 
      is_lab_ordered = Encounter.joins(:type).where(
        'encounter_type.name = ? AND encounter.patient_id = ?',
        LAB_ORDERS,
        @patient.patient_id
      ).exists?

      !is_lab_ordered
    end

    def patient_should_get_treatment?
      prescribe_drugs_concept = concept('Prescribe drugs')
      no_concept = concept('No')
      start_time, end_time = TimeUtils.day_bounds(@date)
      !Observation.where(
        'concept_id = ? AND value_coded = ? AND person_id = ?
         AND obs_datetime BETWEEN ? AND ?',
        prescribe_drugs_concept.concept_id, no_concept.concept_id,
        @patient.patient_id, start_time, end_time
      ).exists?
    end

    def patient_got_treatment?
      encounter_type = EncounterType.find_by name: TREATMENT
      encounter = Encounter.select('encounter_id').where(
        'patient_id = ? AND encounter_type = ? AND DATE(encounter_datetime) = DATE(?)',
        @patient.patient_id, encounter_type.encounter_type_id, @date
      ).order(encounter_datetime: :desc).first
      !encounter.nil? && encounter.orders.exists?
    end

    def patient_has_not_completed_fast_track_visit?
      return !@fast_track_completed if @fast_track_completed

      @fast_track_completed = Observation.where(concept: concept('Fast track visit'),
                                                person: @patient.person)\
                                         .where('obs_datetime BETWEEN ? AND ?', *TimeUtils.day_bounds(@date))
                                         .order(obs_datetime: :desc)\
                                         .first
                                         &.value_coded&.to_i == concept('Yes').concept_id

      !@fast_track_completed
    end

  end
end
