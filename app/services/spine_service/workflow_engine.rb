# frozen_string_literal: true

require 'set'

module SpineService
  # rubocop:disable Metrics/ClassLength
  # This class implements a state machine that determines the next encounter
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
    ADMIT_PATIENT = 'ADMIT PATIENT'
    UPDATE_OUTCOME = 'PATIENT OUTCOME'
    PATIENT_DIAGNOSIS = 'OUTPATIENT DIAGNOSIS'
    HIV_STATUS = 'UPDATE HIV STATUS'
    TREATMENT = 'TREATMENT'

    ENCOUNTER_SM = {
      INITIAL_STATE => HIV_STATUS,
      HIV_STATUS => PATIENT_DIAGNOSIS,
      PATIENT_DIAGNOSIS => TREATMENT,
      TREATMENT => END_STATE
    }.freeze

    STATE_CONDITIONS = {
      HIV_STATUS => %i[patient_does_not_have_hiv_status_today? patient_has_outcome_today?],
      PATIENT_DIAGNOSIS => %i[patient_does_not_have_diagnosis_today? patient_has_outcome_today?],
      TREATMENT => %i[patient_does_not_have_prescription? patient_has_outcome_today?]
    }.freeze

    def next_state(current_state)
      ENCOUNTER_SM[current_state]
    end

    # Check if a relevant encounter of given type exists for given patient.
    #
    # NOTE: By `relevant` above we mean encounters that matter in deciding
    # what encounter the patient should go for in this present time.
    def encounter_exists?(type)
      Encounter.where(type: type, patient: @patient, program: @program)\
               .where('encounter_datetime BETWEEN ? AND ?', *TimeUtils.day_bounds(@date))\
               .exists?
    end

    def valid_state?(state)
      return false if encounter_exists?(encounter_type(state))

      (STATE_CONDITIONS[state] || []).reduce(true) do |status, condition|
        status && method(condition).call
      end
    end

    def patient_does_not_have_hiv_status_today?
      # we need to check if the patient is on ART or reactive
      # if the patient is negative then we do another check of whether this check was during this visit
      status_concept = ConceptName.find_by_name('HIV status').concept_id
      admit_type = EncounterType.find_by name: ADMIT_PATIENT
      latest_status = Observation.where(person_id: @patient.id, concept_id: status_concept)\
                                 .where('DATE(obs_datetime) <= DATE(?)', @date)\
                                 .order(obs_datetime: :desc).first
      latest_admission = Encounter.joins(:type)
                                  .where(patient_id: @patient.id, program_id: @program.program_id)\
                                  .where('DATE(encounter_datetime) <= DATE(?) AND encounter_type = ?', @date, admit_type.id)\
                                  .order(encounter_datetime: :desc).first

      return true if latest_status.blank?
      return false if latest_status.value_coded == ConceptName.find_by_name('Reactive').concept_id
      return false if latest_status.value_coded == ConceptName.find_by_name('Positive').concept_id
      return false if latest_status.value_text == 'Positive' || latest_status.value_text == 'Reactive'
      return true if latest_admission.present? && latest_status.obs_datetime < latest_admission.encounter_datetime

      true
    end

    def patient_has_outcome_today?
      outcome_type = EncounterType.find_by name: UPDATE_OUTCOME
      outcome_encounter = Encounter.joins(:type).where(
        'patient_id = ? AND encounter_type = ? AND DATE(encounter_datetime) = DATE(?) AND program_id = ?',
        @patient.patient_id, outcome_type.encounter_type_id, @date, @program.program_id
      ).order(encounter_datetime: :desc).first

      outcome_encounter.present?
    end

    def patient_does_not_have_diagnosis_today?
      encounter_type = EncounterType.find_by name: PATIENT_DIAGNOSIS
      encounter = Encounter.joins(:type).where(
        'patient_id = ? AND encounter_type = ? AND DATE(encounter_datetime) = DATE(?)',
        @patient.patient_id, encounter_type.encounter_type_id, @date
      ).order(encounter_datetime: :desc).first

      encounter.blank?
    end

    def patient_does_not_have_prescription?
      encounter_type = EncounterType.find_by name: TREATMENT
      encounter = Encounter.joins(:type).where(
        'patient_id = ? AND encounter_type = ? AND DATE(encounter_datetime) = DATE(?)',
        @patient.patient_id, encounter_type.encounter_type_id, @date
      ).order(encounter_datetime: :desc).first

      encounter.blank?
    end
  end
  # rubocop:enable Metrics/ClassLength
end
