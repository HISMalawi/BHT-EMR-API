# frozen_string_literal: true

require 'set'

module HTSService
  class WorkflowEngine
    include ModelUtils

    def initialize(patient:, date: nil, program: nil)
      @patient = patient
      @program = program || program('HTC Program')
      @date = date || Date.today
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
        encounter_type.name = state

        return encounter_type if valid_state?(state)
      end

      nil
    end

    private

    LOGGER = Rails.logger

    # Encounter types
    INITIAL_STATE = 0 # Start terminal for encounters graph
    END_STATE = 1 # End terminal for encounters graph
    PREGNANCY_STATUS = 'PREGNANCY STATUS'
    ITEMS_GIVEN = 'ITEMS GIVEN'
    CIRCUMCISION = 'CIRCUMCISION'
    SOCIAL_HISTORY = 'SOCIAL HISTORY'
    TESTING = 'TESTING'
    APPOINTMENT = 'APPOINTMENT'
    HTS_CONTACT = 'HTS Contact'
    REFERRAL = 'REFERRAL'
    PARTNER_RECEPTION = 'Partner Reception'

    # Encounters graph
    ENCOUNTER_SM = {
      INITIAL_STATE => PREGNANCY_STATUS,
      PREGNANCY_STATUS => CIRCUMCISION,
      CIRCUMCISION => SOCIAL_HISTORY,
      SOCIAL_HISTORY => TESTING,
      TESTING => APPOINTMENT,
      APPOINTMENT => HTS_CONTACT,
      HTS_CONTACT => ITEMS_GIVEN,
      ITEMS_GIVEN => REFERRAL,
      REFERRAL => PARTNER_RECEPTION,
      PARTNER_RECEPTION => END_STATE
    }.freeze

    STATE_CONDITIONS = {

      PREGNANCY_STATUS => %i[is_female_client?
                             task_not_done?],

      CIRCUMCISION => %i[is_male_client?
                        task_not_done?],

      SOCIAL_HISTORY => %i[no_social_history?],

      TESTING => %i[task_not_done_today?],

      APPOINTMENT => %i[task_not_done_today?
                      done_screening_today?
                      not_hiv_positive_at_health_facility_accesspoint?],

      HTS_CONTACT => %i[hiv_positive_at_health_facility_accesspoint?],

      ITEMS_GIVEN => %i[task_not_done_today?],

      REFERRAL => %i[task_not_done_today?],

      PARTNER_RECEPTION => %i[task_not_done_today?]

    }.freeze

    def load_user_activities
      activities = user_property('Activities')&.property_value
      encounters = (activities&.split(',') || []).collect do |activity|
        # Re-map activities to encounters
        case activity
        when /PREGNANCY STATUS/i
          PREGNANCY_STATUS
        when /CIRCUMCISION/i
          CIRCUMCISION
        when /SOCIAL HISTORY|MARITAL/i
          SOCIAL_HISTORY
        when /TESTING/i
          TESTING
        when /APPOINTMENT/i
          APPOINTMENT
        when /CONTACT/i
          HTS_CONTACT
        when /ITEMS GIVEN/i
          ITEMS_GIVEN
        when /REFERRAL/i
          REFERRAL
        when /Partner Reception/i
          PARTNER_RECEPTION
        else
          Rails.logger.warn "Invalid HTS activity in user properties: #{activity}"
        end
      end
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

      return false if encounter_exists?(encounter_type(state)) || !@activities.include?(state)

      (STATE_CONDITIONS[state] || []).all? { |condition| send(condition) }
    end

    def is_male_client?
      @patient.gender == "M"
    end

    def is_female_client?
      @patient.gender == "F"
    end

    def task_not_done?
      Encounter.where(type: @encounter, patient: @patient, program: @program).blank?
    end

    def done_screening_today?

      encounter_type = EncounterType.find_by name: "TESTING"
      Encounter.where(type:encounter_type, patient: @patient, program: @program)\
        .where('encounter_datetime BETWEEN ? AND ?', *TimeUtils.day_bounds(@date))\
        .exists?
    end

    def no_social_history?
      Encounter.where(type: @encounter, patient: @patient, program: @program).blank?
    end

    def task_not_done_today?
      encounter_type = EncounterType.find_by name: @encounter.name
      Encounter.where(patient: @patient, type: encounter_type, program: @program)\
              .where('encounter_datetime BETWEEN ? AND ?', *TimeUtils.day_bounds(@date))\
              .blank?
    end

    def hiv_positive_at_health_facility_accesspoint?
      access = Observation.joins(:encounter)
                          .where(concept: concept('HTS Access Type'),
                              person: @patient.person,
                              encounter: {
                                program_id: @program.program_id,
                                encounter_type: encounter_type('Testing')
                              })
                          .where('obs_datetime BETWEEN ? AND ?', *TimeUtils.day_bounds(@date))
                          .last
      return false if access.blank?
      concept('Health Facility').concept_id === access.value_coded && is_hiv_positive?
    end

    def not_hiv_positive_at_health_facility_accesspoint?
      !hiv_positive_at_health_facility_accesspoint?
    end

    def is_hiv_positive?
      status = Observation.joins(:encounter)\
                          .where(concept: concept('HIV status'),
                                person: @patient.person,
                                encounter: { program_id: @program.program_id })\
                          .where('obs_datetime BETWEEN ? AND ?', *TimeUtils.day_bounds(@date))
                          .last
      return false if status.blank?
      concept('Positive').concept_id === status.value_coded
    end
  end
end