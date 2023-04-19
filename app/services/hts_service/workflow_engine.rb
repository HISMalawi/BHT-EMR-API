# frozen_string_literal: true

require "set"

module HTSService
  class WorkflowEngine
    include ModelUtils

    def initialize(patient:, date: nil, program: nil)
      @patient = patient
      @program = program || program("HTC Program")
      @date = date || Date.today
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
    PREGNANCY_STATUS = "PREGNANCY STATUS"
    ITEMS_GIVEN = "ITEMS GIVEN"
    CIRCUMCISION = "CIRCUMCISION"
    SOCIAL_HISTORY = "SOCIAL HISTORY"
    TESTING = "TESTING"
    RECENCY = "RECENCY"
    DBS_ORDER = "DBS ORDER"
    APPOINTMENT = "APPOINTMENT"
    HTS_CONTACT = "HTS Contact"
    REFERRAL = "REFERRAL"
    PARTNER_RECEPTION = "Partner Reception"
    ART_INITIATION = "ART Enrollment"

    # Encounters graph
    ENCOUNTER_SM = {
      INITIAL_STATE => PREGNANCY_STATUS,
      PREGNANCY_STATUS => CIRCUMCISION,
      CIRCUMCISION => SOCIAL_HISTORY,
      SOCIAL_HISTORY => TESTING,
      TESTING => RECENCY,
      RECENCY => DBS_ORDER,
      DBS_ORDER => PARTNER_RECEPTION,
      PARTNER_RECEPTION => APPOINTMENT,
      APPOINTMENT => HTS_CONTACT,
      HTS_CONTACT => ITEMS_GIVEN,
      ITEMS_GIVEN => ART_INITIATION,
      ART_INITIATION => REFERRAL,
      REFERRAL => END_STATE,
    }.freeze

    STATE_CONDITIONS = {

      DBS_ORDER => %i[not_from_community_accesspoint? task_not_done_today? eligible_for_dbs?],

      PREGNANCY_STATUS => %i[is_female_client?
                             task_not_done_today?],

      CIRCUMCISION => %i[is_male_client?
                         client_not_circumcised?
                         task_not_done_today?],

      SOCIAL_HISTORY => %i[no_social_history?],

      TESTING => %i[task_not_done_today?],

      RECENCY => %i[not_from_community_accesspoint? can_perform_recency?],

      APPOINTMENT => %i[does_not_have_two_incoclusive_results?
                        task_not_done_today?
                        done_screening_today?
                        not_hiv_positive_at_health_facility_accesspoint?],

      ART_INITIATION => %i[no_art_referral?
                           hiv_positive_at_health_facility_accesspoint?],

      HTS_CONTACT => %i[hiv_positive_at_health_facility_accesspoint?],

      ITEMS_GIVEN => %i[task_not_done_today?],

      REFERRAL => %i[task_not_done_today?],

      PARTNER_RECEPTION => %i[task_not_done_today?
                              not_from_community_accesspoint?],
    }.freeze

    def next_state(current_state)
      ENCOUNTER_SM[current_state]
    end

    def encounter_exists?(type)
      @encounter = type
      Encounter.where(type: type, patient: @patient, program: @program).where("encounter_datetime BETWEEN ? AND ?", *TimeUtils.day_bounds(@date)).exists?
    end

    def valid_state?(state)
      return false if encounter_exists?(encounter_type(state))

      (STATE_CONDITIONS[state] || []).all? { |condition| send(condition) }
    end

    def is_male_client?
      @patient.gender == "M"
    end

    def is_female_client?
      @patient.gender == "F"
    end

    def eligible_for_dbs?
      # patient over 12 months then both current and previous test results are inconclusive
      # patient less than 12 months with HIV positive result
      if recency_is_recent?
        return true
      end
      if age_below_1? && hiv_positive_at_health_facility_accesspoint?
        return true
      elsif !age_below_1? && !does_not_have_two_incoclusive_results?
        return true
      end
      return false
    end

    def recency_is_recent?
      recency_obs = Observation.joins(:encounter).where(
        person: @patient.person,
        concept_id: concept("Recency Test").concept_id,
        encounter: {
          program_id: @program.program_id,
          encounter_type: encounter_type("RECENCY"),
        },
      ).where("encounter_datetime BETWEEN ? AND ?", *TimeUtils.day_bounds(@date))
        .order("encounter_datetime DESC")
      return false if recency_obs.blank?
      return true if recency_obs.last.answer_string&.strip == "Recent"
      return false
    end

    def not_eligible_for_dbs?
      !eligible_for_dbs?
    end

    def age_below_1?
      @patient.age_in_months < 12
    end

    def does_not_have_two_incoclusive_results?
      !%i[previous_tested_incoclusive? current_test_is_inconclusive?].all? { |condition| send(condition) }
    end

    def previous_tested_incoclusive?
      obs = Observation.joins(:encounter).where(
        person: @patient.person,
        concept_id: concept("Previous HIV Test Results").concept_id,
        encounter: {
          program_id: @program.program_id,
          encounter_type: encounter_type("TESTING"),
        },
      ).where("encounter_datetime BETWEEN ? AND ?", *TimeUtils.day_bounds(@date))
        .order("encounter_datetime DESC")
      return false if obs.blank?
      return true if /inconclusive/.match?(obs.last.answer_string&.downcase)
      return false
    end

    def current_test_is_inconclusive?
      obs = Observation.joins(:encounter).where(
        person: @patient.person,
        concept_id: concept("HIV status").concept_id,
        encounter: {
          program_id: @program.program_id,
          encounter_type: encounter_type("TESTING"),
        },
      ).where("encounter_datetime BETWEEN ? AND ?", *TimeUtils.day_bounds(@date))
        .order("encounter_datetime DESC")
      return false if obs.blank?
      return true if /inconclusive/.match?(obs.last.answer_string&.downcase)
      return false
    end

    def test_two_done?
      Observation.joins(:encounter).where(
        person: @patient.person,
        concept_id: concept("Test 2").concept_id,
        encounter: {
          program_id: @program.program_id,
          encounter_type: encounter_type("TESTING"),
        },
      ).where("encounter_datetime BETWEEN ? AND ?", *TimeUtils.day_bounds(@date))
        .order("encounter_datetime DESC").exists?
    end

    def can_perform_recency?
      %i[test_two_done? recency_activated? recency_in_user_properties?].all? { |condition| send(condition) }
    end

    def recency_in_user_properties?
      properties = UserProperty.where(
        user_id: User.current.id,
        property: "HTS_PROGRAMS",
      ).first
      properties = properties.property_value.split(",") rescue []
      return false if properties.blank?
      return false if !properties.include?("Recency")
      true
    end

    def recency_activated?
      GlobalProperty.where(property: "hts.recency.test")&.last&.property_value == "true"
    end

    def client_not_circumcised?
      status = Observation.joins(:encounter)
                          .where(concept: concept("Circumcision status"),
                                 person: @patient.person,
                                 encounter: {
                                   program_id: @program.program_id,
                                   encounter_type: encounter_type("CIRCUMCISION"),
                                 })
                          .where("obs_datetime <= ?", @date)
                          .last
      return true if status.blank?
      concept("No").concept_id === status.value_coded
    end

    def task_not_done?
      Encounter.where(type: @encounter, patient: @patient, program: @program).blank?
    end

    def done_screening_today?
      encounter_type = EncounterType.find_by name: "TESTING"
      Encounter.where(type: encounter_type, patient: @patient, program: @program).where("encounter_datetime BETWEEN ? AND ?", *TimeUtils.day_bounds(@date)).exists?
    end

    def no_social_history?
      Encounter.where(type: @encounter, patient: @patient, program: @program).blank?
    end

    def task_not_done_today?
      encounter_type = EncounterType.find_by name: @encounter.name
      Encounter.where(patient: @patient, type: encounter_type, program: @program).where("encounter_datetime BETWEEN ? AND ?", *TimeUtils.day_bounds(@date)).blank?
    end

    def from_community_accesspoint?
      access = Observation.joins(:encounter)
                          .where(concept: concept("HTS Access Type"),
                                 person: @patient.person,
                                 encounter: {
                                   program_id: @program.program_id,
                                   encounter_type: encounter_type("Testing"),
                                 })
                          .where("obs_datetime BETWEEN ? AND ?", *TimeUtils.day_bounds(@date))
                          .last
      return false if access.blank?
      concept("Community").concept_id === access.value_coded
    end

    def hiv_positive_at_health_facility_accesspoint?
      access = Observation.joins(:encounter)
                          .where(concept: concept("HTS Access Type"),
                                 person: @patient.person,
                                 encounter: {
                                   program_id: @program.program_id,
                                   encounter_type: encounter_type("Testing"),
                                 })
                          .where("obs_datetime BETWEEN ? AND ?", *TimeUtils.day_bounds(@date))
                          .last
      return false if access.blank?
      concept("Health Facility").concept_id === access.value_coded && is_hiv_positive?
    end

    def no_art_referral?
      referral = Observation.joins(:encounter)
        .where(concept: concept("ART referral"),
               person: @patient.person,
               encounter: {
                 program_id: @program.program_id,
                 encounter_type: encounter_type(ART_INITIATION),
               })
        .where("obs_datetime BETWEEN ? AND ?", *TimeUtils.day_bounds(@date))
        .last
      return true if referral.blank?
      concept("No").concept_id === referral.value_coded
    end

    def is_hiv_positive?
      status = Observation.joins(:encounter).where(concept: concept("HIV status"),
                                                   person: @patient.person,
                                                   encounter: { program_id: @program.program_id }).where("obs_datetime BETWEEN ? AND ?", *TimeUtils.day_bounds(@date))
        .last
      return false if status.blank?
      concept("Positive").concept_id === status.value_coded
    end

    def not_hiv_positive_at_health_facility_accesspoint?
      !hiv_positive_at_health_facility_accesspoint?
    end

    def not_from_community_accesspoint?
      !from_community_accesspoint?
    end
  end
end
