# frozen_string_literal: true

require 'set'

module CXCAService
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
    END_STATE = 1 # End terminal for encounters graphCxCa_TEST = 'CXCA TEST'
    CXCA_RECEPTION = 'CXCA RECEPTION'
    CXCA_TEST = 'CXCA TEST'
    CXCA_SCREENING_RESULTS = 'CXCA screening result'
    CANCER_TREATMENT = 'CxCa treatment'
    APPOINTMENT = 'APPOINTMENT'

    # Encounters graph
    ENCOUNTER_SM = {
      INITIAL_STATE => CXCA_TEST,
      CXCA_TEST => CXCA_SCREENING_RESULTS,
      CXCA_SCREENING_RESULTS => CANCER_TREATMENT,
      CANCER_TREATMENT => APPOINTMENT,
      APPOINTMENT => END_STATE
    }.freeze

    STATE_CONDITIONS = {
      CXCA_TEST => %i[show_cxca_test?],
      CXCA_SCREENING_RESULTS => %i[show_cxca_screening_results?],
      CANCER_TREATMENT => %i[show_cancer_treatment?],
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
    def show_cxca_test?
      return false if cxca_positive?

      encounter_type = EncounterType.find_by name: CXCA_TEST
      encounter = Encounter.joins(:type).where(
        'patient_id = ? AND encounter_type = ? AND DATE(encounter_datetime) = DATE(?)',
        @patient.patient_id, encounter_type.encounter_type_id, @date
      ).order(encounter_datetime: :desc).first

      encounter.blank?
    end

    # Check if patient has been offered VIA and results is positive
    def show_treatment?
      return false if cxca_positive?

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
      encounter_type = EncounterType.find_by name: APPOINTMENT
      encounter = Encounter.joins(:type).where(
        'patient_id = ? AND encounter_type = ? AND DATE(encounter_datetime) = DATE(?)
        AND program_id = ?', @patient.patient_id, encounter_type.encounter_type_id, @date,
      @program.program_id).order(encounter_datetime: :desc).first

      return true if encounter.blank? && cxca_not_offered? && !waiting_for_lab_results?
      #return true if cxca_not_offered?
      #return true if waiting_for_lab_results?

      return false
    end

    def show_cxca_screening_results?
      encounter_type = EncounterType.find_by name: CXCA_TEST
      encounter = Encounter.joins(:type).where(
        'patient_id = ? AND encounter_type = ? AND DATE(encounter_datetime) = DATE(?)',
        @patient.patient_id, encounter_type.encounter_type_id, @date
      ).order(encounter_datetime: :desc).first

      unless encounter.blank?
        waiting_for_test = concept('Waiting for test results').concept_id
        no_concept = concept('No').concept_id

        return encounter.observations.find_by("concept_id = ? AND value_coded IN(?)",
          waiting_for_test, [no_concept]).blank? == false ? true : false
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
      encounter_type = EncounterType.find_by name: CXCA_SCREENING_RESULTS #CANCER_TREATMENT
      encounter = Encounter.joins(:type).where(
        'patient_id = ? AND encounter_type = ? AND DATE(encounter_datetime) = DATE(?)',
        @patient.patient_id, encounter_type.encounter_type_id, @date
      ).order(encounter_datetime: :desc).first

      unless encounter.blank?
=begin
        positive_concept_ids = [concept('VIA positive').concept_id]
        positive_concept_ids << concept('PAP Smear abnormal').concept_id
        positive_concept_ids << concept('HPV positive').concept_id
        positive_concept_ids << concept('Visible Lesion').concept_id

        screening_result = concept('Screening results').concept_id

        positive_obs = encounter.observations.find_by("concept_id = ?
          AND value_coded IN(?)", screening_result, positive_concept_ids)
=end
        treatment_option_concept_id  = concept('Directly observed treatment option').concept_id
        same_day_concept_id  = concept('Same day treatment').concept_id

        same_day_treatment = encounter.observations.find_by("concept_id = ?
          AND value_coded IN(?)", treatment_option_concept_id, [same_day_concept_id])

        if same_day_treatment
          encounter_type = EncounterType.find_by name: CANCER_TREATMENT
          cxca_encounter = Encounter.joins(:type).where(
            'patient_id = ? AND encounter_type = ? AND DATE(encounter_datetime) = DATE(?)',
            @patient.patient_id, encounter_type.encounter_type_id, @date
          ).order(encounter_datetime: :desc).first
          return true if cxca_encounter.blank?
        end


      end

      encounter_type = EncounterType.find_by name: CXCA_TEST
      encounter = Encounter.joins(:type).where(
        'patient_id = ? AND encounter_type = ? AND DATE(encounter_datetime) = DATE(?)',
        @patient.patient_id, encounter_type.encounter_type_id, @date
      ).order(encounter_datetime: :desc).first

      unless encounter.blank?
        reason_for_visit_concept_id  = concept('Reason for visit').concept_id
        postponed_treatment  = concept('Postponed treatment').concept_id

        postponed = encounter.observations.find_by("concept_id = ?
          AND value_coded IN(?)", reason_for_visit_concept_id, [postponed_treatment])

          return true unless postponed.blank?
      end

      return false
    end

    def show_reception?
      encounter_type = EncounterType.find_by name: CXCA_RECEPTION
      encounter = Encounter.joins(:type).where(
        'patient_id = ? AND encounter_type = ? AND DATE(encounter_datetime) = DATE(?)',
        @patient.patient_id, encounter_type.encounter_type_id, @date
      ).order(encounter_datetime: :desc).first

      return encounter.blank? ? false : true
    end

    private

    def cxca_positive?
      encounter_type = EncounterType.find_by name: CXCA_TEST
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

    def waiting_for_lab_results?
      encounter_type = EncounterType.find_by name: CXCA_TEST
      encounter = Encounter.joins(:type).where(
        'patient_id = ? AND encounter_type = ? AND DATE(encounter_datetime) < DATE(?)',
        @patient.patient_id, encounter_type.encounter_type_id, @date
      ).order(encounter_datetime: :desc).first

      unless encounter.blank?
        waiting_for_test = concept('Waiting for test results').concept_id
        yes_concept = concept('Yes').concept_id

        return encounter.observations.find_by("concept_id = ? AND value_coded IN(?)",
          waiting_for_test, [yes_concept]).blank? == false ? true : false
      end

      return false
    end

    def cxca_not_offered?
      encounter_type = EncounterType.find_by name: CXCA_TEST
      encounter = Encounter.joins(:type).where(
        'patient_id = ? AND encounter_type = ? AND DATE(encounter_datetime) < DATE(?)',
        @patient.patient_id, encounter_type.encounter_type_id, @date
      ).order(encounter_datetime: :desc).first

      unless encounter.blank?
        reason_for_no_cxca = concept('Reason for NOT offering CxCa').concept_id
        reason_for_no_cxca = encounter.observations.find_by("concept_id = ?",  reason_for_no_cxca)
        return true if reason_for_no_cxca.blank?
      end

      return true
    end

    def concept(name)
      ConceptName.find_by_name(name)
    end

  end
end
