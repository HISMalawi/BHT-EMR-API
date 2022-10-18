# frozen_string_literal: true

require 'htn_workflow'
require 'set'

module HTSService
  class WorkflowEngine
    include ModelUtils

    def initialize(patient:, date: nil, program: nil)
      @patient = patient
      @program = program || load_hts_program
      @date = date || Date.today
    end

    # Retrieves the next encounter for bound patient
    def next_encounter
      state = INITIAL_STATE
      loop do
        state = next_state state
        break if state == END_STATE

        LOGGER.debug "Loading encounter type: #{state}"
        encounter = load_states(state)

        encounter_type = EncounterType.find_by(name: state)
        encounter_type.name = encounter

          return htn_transform(encounter_type) if valid_state?(state)
      end

      nil
    end

    private

    LOGGER = Rails.logger

    # Encounter types
    INITIAL_STATE = 0 # Start terminal for encounters graph
    END_STATE = 1 # End terminal for encounters graph
    PREGNANCY_STATUS = 'PREGNANCY STATUS'
    CIRCUMCISION = 'CIRCUMCISION'
    SOCIAL_HISTORY = 'SOCIAL HISTORY'
    SCREENING = 'SCREENING'
    APPOINTMENT = 'APPOINTMENT'
    HTS_Contact = 'HTS Contact'
    REFERRAL = 'REFERRAL'
    PARTNER_RECEPTION = 'Partner Reception'

    # Encounters graph
    ENCOUNTER_SM = {
      INITIAL_STATE => PREGNANCY_STATUS,
      PREGNANCY_STATUS => CIRCUMCISION,
      CIRCUMCISION => SOCIAL_HISTORY,
      SOCIAL_HISTORY => SCREENING,
      SCREENING => APPOINTMENT,
      APPOINTMENT => REFERRAL,
      REFERRAL => PARTNER_RECEPTION,
      PARTNER_RECEPTION => END_STATE
    }.freeze

    STATE_CONDITIONS = {

      PREGNANCY_STATUS => %i[gender_based_encounter_check?],

      CIRCUMCISION => %i[gender_based_encounter_check?],

      SOCIAL_HISTORY => %i[marital_status_track?],

      SCREENING => %i[workflow_status_track?],

      APPOINTMENT => %i[workflow_status_track?],

      REFERRAL => %i[workflow_status_track?],

      PARTNER_RECEPTION => %i[workflow_status_track?
                              check_hiv_results_status?],

    }.freeze

    # Concepts

    def load_states (encounter)

      case encounter

        when 'PREGNANCY STATUS'
            state = "PREGNANCY STATUS"
        when "CIRCUMCISION"
           state = "CIRCUMCISION STATUS"
        when 'SOCIAL HISTORY'
           state = "SOCIAL HISTORY"
        when 'SCREENING'
           state = "SCREENING"
        when "REFERRAL"
            state ="REFERRAL"
        when "HTS Contact"
            state ="CONTACT"
        when 'APPOINTMENT'
            state = "REFERRAL APPOINTMENT"
        when "Partner Reception"
             state ='PARTNER RECEPTION'
        end

       return state

    end

    def next_state(current_state)
      ENCOUNTER_SM[current_state]
    end


    def encounter_exists?(type)

         @encounter = type
         Encounter.where(type: type, patient: @patient, program: @program)\
                  .where('encounter_datetime BETWEEN ? AND ?', *TimeUtils.day_bounds(@date))\
                  .exists?

    end

    def valid_state?(state)

      return false if encounter_exists?(encounter_type(state))

             (STATE_CONDITIONS[state] || []).all? { |condition| send(condition) }
    end

    def gender_based_encounter_check?

            status = Encounter.where(type: @encounter, patient: @patient, program: @program).exists?
            case @encounter.name

                when 'PREGNANCY STATUS'
                     return true if @patient.gender == "F" && status == false

                when "CIRCUMCISION"
                     return true if @patient.gender == "M" && status == false
            end
    end

    def marital_status_track?

           concept_id = ConceptName.find_by_name('Civil status').concept_id
           status = Observation.where(concept_id: concept_id, person_id: @patient.id).exists?
           return true if status == false
    end

    def workflow_status_track?

      encounter_type = EncounterType.find_by name: @encounter.name
      encounter = Encounter.where(patient: @patient, type: encounter_type, program: @program)\
                           .where('encounter_datetime BETWEEN ? AND ?', *TimeUtils.day_bounds(@date))\
                           .order(encounter_datetime: :desc)\
                           .first
      return true if encounter.blank?

    end

     def check_hiv_results_status?

       return true if true == Observation.joins(:encounter)\
                                         .where(concept: concept('HIV status'),
                                                person: @patient.person,
                                                value_coded: concept('Positive').concept_id,
                                                encounter: { program_id: @program.program_id })\
                                         .where('obs_datetime BETWEEN ? AND ?', *TimeUtils.day_bounds(@date))
                                         .order(obs_datetime: :desc)\
                                         .exists?
    end

    def htn_transform(encounter_type)
      htn_activated = global_property('activate.htn.enhancement')&.property_value&.downcase == 'true'
      return encounter_type unless htn_activated

      htn_workflow.next_htn_encounter(@patient, encounter_type, @date)
    end

    def htn_workflow
      HtnWorkflow.new
    end

    def load_hts_program
        program('HTC Program')
    end
  end
end





