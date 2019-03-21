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
    SOCIAL_HISTORY = "SOCIAL HISTORY"
    LAB_RESULTS = 'LAB RESULTS'
    CURRENT_PREGNANCY = 'CURRENT PREGNANCY' # ASSESMENT[sic] - It's how its named in the db
    ANC_EXAMINATION = 'ANC EXAMINATION'
    APPOINTMENT = 'APPOINTMENT'
    TREATMENT = 'TREATMENT'
    HIV_RECEPTION = 'HIV RECEPTION'
    ART_FOLLOWUP = 'ART_FOLLOWUP'

    ONE_TIME_ENCOUNTERS = [
      OBSTETRIC_HISTORY,MEDICAL_HISTORY,
      SURGICAL_HISTORY,SOCIAL_HISTORY
    ]

    # Encounters graph
    ENCOUNTER_SM = {
      INITIAL_STATE => DISPENSING,
      DISPENSING => VITALS,
      VITALS => ANC_VISIT_TYPE,
      ANC_VISIT_TYPE => OBSTETRIC_HISTORY,
      OBSTETRIC_HISTORY => MEDICAL_HISTORY,
      MEDICAL_HISTORY => SURGICAL_HISTORY,
      SURGICAL_HISTORY => SOCIAL_HISTORY,
      SOCIAL_HISTORY => LAB_RESULTS,
      LAB_RESULTS => CURRENT_PREGNANCY,
      CURRENT_PREGNANCY => ANC_EXAMINATION,
      ANC_EXAMINATION => APPOINTMENT,
      APPOINTMENT => TREATMENT,
      TREATMENT => HIV_RECEPTION,
      HIV_RECEPTION => ART_FOLLOWUP,
      ART_FOLLOWUP => END_STATE
    }.freeze

    STATE_CONDITIONS = {
      DISPENSING => %i[patient_has_not_been_given_ttv?],
      OBSTETRIC_HISTORY => %i[is_not_a_subsequent_visit?
                      obstetric_history_not_collected?],
      MEDICAL_HISTORY => %i[is_not_a_subsequent_visit?
                        medical_history_not_collected?],
      SURGICAL_HISTORY => %i[is_not_a_subsequent_visit?
                        surgical_history_not_collected?],
      SOCIAL_HISTORY => %i[is_not_a_subsequent_visit?
                          social_history_not_collected?],
=begin
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
      if !ONE_TIME_ENCOUNTERS.include?(state)
        return false if encounter_exists?(encounter_type(state))
      end

      (STATE_CONDITIONS[state] || []).reduce(true) do |status, condition|
        status && method(condition).call
      end
    end

    # Check if patient is not been given ttv
    def patient_has_not_been_given_ttv?
      ttv_drug = Drug.find_by name: "TTV (0.5ml)"
      ttv_order = Encounter.joins(:orders => [:drug_order])
        .where("encounter.patient_id = ? AND drug_order.drug_inventory_id = ?
          AND DATE(encounter.encounter_datetime) = DATE(?)",
          @patient.patient_id, ttv_drug.id, @date)
        .order(encounter_datetime: :desc).first.blank?

      ttv_order
    end

    # Check if surgical history has been collected

    def surgical_history_not_collected?
      lmp_date = date_of_lnmp
      return true if lmp_date.nil?

      surgical_history_enc = EncounterType.find_by name: SURGICAL_HISTORY
      surg_history = Encounter.where("encounter_type = ?
          AND patient_id = ? AND DATE(encounter_datetime) >= DATE(?)",
          surgical_history_enc.id, @patient.patient_id, lmp_date).blank?
          
      surg_history
    end

    # Checks if this is the subsequent visit
    #
    def is_not_a_subsequent_visit?
      lmp_date = date_of_lnmp
      return true if lmp_date.nil?

      visit_type = EncounterType.find_by name: ANC_VISIT_TYPE
      reason_for_visit = ConceptName.find_by name: "Reason for visit"

      anc_visit = Encounter.joins(:observations).where("encounter.encounter_type = ?
          AND concept_id = ? AND encounter.patient_id = ? AND 
          DATE(encounter.encounter_datetime) >= DATE(?)",
          visit_type.id, reason_for_visit.concept_id, 
          @patient.patient_id, lmp_date)
        .order(encounter_datetime: :desc).first.blank?

      anc_visit
    end

    def obstetric_history_not_collected?
      lmp_date = date_of_lnmp
      return true if lmp_date.nil?

      obstetric_encounter = EncounterType.find_by name: OBSTETRIC_HISTORY
      
      obstetric = Encounter.where("encounter_type = ?
          AND patient_id = ? AND DATE(encounter_datetime) >= DATE(?)",
          obstetric_encounter.id, @patient.patient_id, lmp_date)
        .order(encounter_datetime: :desc).first.blank?

      obstetric
    end

    def medical_history_not_collected?
      lmp_date = date_of_lnmp
      return true if lmp_date.nil?

      medical_history_enc = EncounterType.find_by name: MEDICAL_HISTORY

      med_history = Encounter.where("encounter_type = ?
          AND patient_id = ? AND DATE(encounter_datetime) >= DATE(?)",
          medical_history_enc.id, @patient.patient_id, lmp_date)
        .order(encounter_datetime: :desc).first.blank?

      med_history
    end

    def social_history_not_collected?
      lmp_date = date_of_lnmp
      return true if lmp_date.nil?

      social_history_enc = EncounterType.find_by name: SOCIAL_HISTORY

      social_history = Encounter.where("encounter_type = ?
          AND patient_id = ? AND DATE(encounter_datetime) >= DATE(?)",
          social_history_enc.id, @patient.patient_id, lmp_date)
        .order(encounter_datetime: :desc).first.blank?

      social_history
    end

    def date_of_lnmp
      lmp = ConceptName.find_by name: "Last menstrual period"
      current_pregnancy = EncounterType.find_by name: CURRENT_PREGNANCY

      last_lmp = @patient.encounters.joins([:observations])
        .where(['encounter_type = ? AND obs.concept_id = ?',
          current_pregnancy.id,lmp.concept_id])
        .last.observations.collect { 
          |o| o.value_datetime 
        }.compact.last.to_date rescue nil
    end

  end
end
