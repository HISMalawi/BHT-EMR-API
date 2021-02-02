# frozen_string_literal: true

require 'set'

module VIAService
  class WorkflowEngine
    include ModelUtils

    def initialize(program:, patient:, date:)
      @patient = patient
      @program = program
      @date = date
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
    VIA_TEST = 'VIA TEST'
    VIA_TREATMENT = 'VIA TREATMENT'
    CANCER_TREATMENT = 'CANCER TREATMENT'
    APPOINTMENT = 'APPOINTMENT'

    # Encounters graph
    ENCOUNTER_SM = {
      INITIAL_STATE => VIA_TEST,
      VIA_TEST =>  VIA_TREATMENT,
      VIA_TREATMENT => CANCER_TREATMENT,
      CANCER_TREATMENT => APPOINTMENT,
      APPOINTMENT  => END_STATE
    }.freeze

    STATE_CONDITIONS = {
      VIA_TEST => %i[show_via_test?],
      VIA_TREATMENT => %i[show_treatment?],
      CANCER_TREATMENT => %i[previous_via_results_positive?
        referred_treatment? show_cancer_treatment?],
      APPOINTMENT => %i[show_appointment?]
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

    # Checks if patient has been asked any VIA related questions today
    #
    def show_via_test?
      return false if via_positive?

      encounter_type = EncounterType.find_by name: VIA_TEST
      encounter = Encounter.joins(:type).where(
        'patient_id = ? AND encounter_type = ? AND DATE(encounter_datetime) = DATE(?)',
        @patient.patient_id, encounter_type.encounter_type_id, @date
      ).order(encounter_datetime: :desc).first

      encounter.blank?
    end

    # Check if patient has been offered VIA and results is positive
    def show_treatment?
      return false if via_positive?

      encounter = Encounter.joins(:type).where(
        'encounter_type.name = ? AND encounter.patient_id = ?
        AND DATE(encounter_datetime) = ?',
        VIA_TEST, @patient.patient_id, @date).order("date_created DESC")

      unless encounter.blank?
        via_result_concept_id = concept('VIA Results').concept_id
        via_positive_result_concept_id = concept('Positive').concept_id

        return encounter.first.observations.find_by(concept_id: via_result_concept_id,
          value_coded: via_positive_result_concept_id).blank? == true ? false : true
      end

      return nil
    end

    def show_appointment?
      return true if via_negative_or_suspected?

      via_treatment = concept('VIA treatment').concept_id
      cryo_treatment = concept('POSITIVE CRYO').concept_id
      thermocoagulation = concept('Thermocoagulation').concept_id

      observations = Observation.where("concept_id  = ?
        AND DATE(obs_datetime) = ? AND person_id  = ?", via_treatment,
        @date, @patient.patient_id)

      unless observations.blank?
        ther_cryo = observations.find_by(value_coded: [cryo_treatment, thermocoagulation])
        return true unless ther_cryo.blank?

      end

      return nil
    end

    def previous_via_results_positive?
      encounter_type = EncounterType.find_by name: VIA_TEST
      encounter = Encounter.joins(:type).where(
        'patient_id = ? AND encounter_type = ? AND DATE(encounter_datetime) < DATE(?)',
        @patient.patient_id, encounter_type.encounter_type_id, @date
      ).order(encounter_datetime: :desc).first

      unless encounter.blank?
        via_result_concept_id = concept('VIA Results').concept_id
        via_positive_result_concept_id = concept('Positive').concept_id

        return encounter.observations.find_by("concept_id = ? AND value_coded IN(?)",
          via_result_concept_id, [via_positive_result_concept_id]).blank? == true ? false : true
      end

      return false
    end

    def referred_treatment?
      via_treatment = concept('VIA treatment').concept_id
      referral_treatment = concept('Referral').concept_id
      cryo_treatment = concept('POSITIVE CRYO').concept_id
      thermocoagulation = concept('Thermocoagulation').concept_id

      observations = Observation.where("concept_id  = ?
        AND DATE(obs_datetime) < ? AND person_id  = ?", via_treatment,
        @date, @patient.patient_id)

      unless observations.blank?
        referred_treatment = observations.find_by(value_coded: [referral_treatment,
        cryo_treatment, thermocoagulation])
        return true unless referred_treatment.blank?

      end

      return nil
    end

    def show_cancer_treatment?
      encounter_type = EncounterType.find_by name: CANCER_TREATMENT
      encounter = Encounter.joins(:type).where(
        'patient_id = ? AND encounter_type = ? AND DATE(encounter_datetime) = DATE(?)',
        @patient.patient_id, encounter_type.encounter_type_id, @date
      ).order(encounter_datetime: :desc).first

      encounter.blank?
    end

    private

    def via_negative_or_suspected?
      encounter_type = EncounterType.find_by name: VIA_TEST
      encounter = Encounter.joins(:type).where(
        'patient_id = ? AND encounter_type = ? AND DATE(encounter_datetime) = DATE(?)',
        @patient.patient_id, encounter_type.encounter_type_id, @date
      ).order(encounter_datetime: :desc).first

      unless encounter.blank?
        via_result_concept_id = concept('VIA Results').concept_id
        via_positive_result_concept_id = concept('Positive').concept_id

        return encounter.observations.find_by("concept_id = ? AND value_coded NOT IN(?)",
          via_result_concept_id, [via_positive_result_concept_id]).blank? == true ? false : true
      end

      return false
    end

    def via_positive?
      encounter_type = EncounterType.find_by name: VIA_TEST
      encounter = Encounter.joins(:type).where(
        'patient_id = ? AND encounter_type = ? AND DATE(encounter_datetime) < DATE(?)',
        @patient.patient_id, encounter_type.encounter_type_id, @date
      ).order(encounter_datetime: :desc).first

      unless encounter.blank?
        via_result_concept_id = concept('VIA Results').concept_id
        via_positive_result_concept_id = concept('Positive').concept_id

        return encounter.observations.find_by("concept_id = ? AND value_coded IN(?)",
          via_result_concept_id, [via_positive_result_concept_id]).blank? == true ? false : true
      end

      return false
    end

    def concept(name)
      ConceptName.find_by_name(name)
    end

  end
end
