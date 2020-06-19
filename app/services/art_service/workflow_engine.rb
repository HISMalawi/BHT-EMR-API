# frozen_string_literal: true

require 'htn_workflow'
require 'set'

module ARTService
  class WorkflowEngine
    include ModelUtils

    def initialize(patient:, date: nil, program: nil)
      @patient = patient
      @program = program || load_hiv_program
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
        if encounter_type.blank? && state == HIV_CLINIC_CONSULTATION_CLINICIAN
          encounter_type = EncounterType.find_by(name: HIV_CLINIC_CONSULTATION)
          encounter_type.name = HIV_CLINIC_CONSULTATION_CLINICIAN
          return encounter_type if referred_to_clinician?
          next
        end

        return htn_transform(encounter_type) if valid_state?(state)
      end

      nil
    end

    private

    LOGGER = Rails.logger

    # Encounter types
    INITIAL_STATE = 0 # Start terminal for encounters graph
    END_STATE = 1 # End terminal for encounters graph
    HIV_CLINIC_REGISTRATION = 'HIV CLINIC REGISTRATION'
    HIV_RECEPTION = 'HIV RECEPTION'
    VITALS = 'VITALS'
    HIV_STAGING = 'HIV STAGING'
    HIV_CLINIC_CONSULTATION = 'HIV CLINIC CONSULTATION'
    ART_ADHERENCE = 'ART ADHERENCE'
    HIV_CLINIC_CONSULTATION_CLINICIAN = 'HIV CLINIC CONSULTATION (clinician)'
    TREATMENT = 'TREATMENT'
    FAST_TRACK = 'FAST TRACK ASSESMENT' # ASSESMENT[sic] - It's how its named in the db
    DISPENSING = 'DISPENSING'
    APPOINTMENT = 'APPOINTMENT'

    # Encounters graph
    ENCOUNTER_SM = {
      INITIAL_STATE => HIV_CLINIC_REGISTRATION,
      HIV_CLINIC_REGISTRATION => HIV_RECEPTION,
      HIV_RECEPTION => VITALS,
      VITALS => HIV_STAGING,
      HIV_STAGING => HIV_CLINIC_CONSULTATION,
      HIV_CLINIC_CONSULTATION => ART_ADHERENCE,
      ART_ADHERENCE => HIV_CLINIC_CONSULTATION_CLINICIAN,
      HIV_CLINIC_CONSULTATION_CLINICIAN => TREATMENT,
      TREATMENT => FAST_TRACK,
      FAST_TRACK => DISPENSING,
      DISPENSING => APPOINTMENT,
      APPOINTMENT => END_STATE
    }.freeze

    STATE_CONDITIONS = {
      HIV_CLINIC_REGISTRATION => %i[patient_not_registered?
                                    patient_not_visiting?],
      VITALS => %i[patient_checked_in?
                   patient_not_on_fast_track?
                   patient_has_not_completed_fast_track_visit?
                   patient_does_not_have_height_and_weight?],
      HIV_STAGING => %i[patient_not_already_staged?
                        patient_has_not_completed_fast_track_visit?],
      HIV_CLINIC_CONSULTATION => %i[patient_not_on_fast_track?
                                    patient_has_not_completed_fast_track_visit?],
      ART_ADHERENCE => %i[patient_received_art?
                          patient_has_not_completed_fast_track_visit?],
      HIV_CLINIC_CONSULTATION_CLINICIAN => %i[patient_not_on_fast_track?
                                    patient_has_not_completed_fast_track_visit?],
      TREATMENT => %i[patient_should_get_treatment?
                      patient_has_not_completed_fast_track_visit?],
      FAST_TRACK => %i[fast_track_activated?
                       patient_got_treatment?
                       patient_not_on_fast_track?
                       patient_has_not_completed_fast_track_visit?],
      DISPENSING => %i[patient_got_treatment?
                       patient_has_not_completed_fast_track_visit?],
      APPOINTMENT => %i[patient_got_treatment?
                        dispensing_complete?]
    }.freeze

    # Concepts
    PATIENT_PRESENT = 'Patient present'
    MINOR_AGE_LIMIT = 18  # Above this age, patient is considered an adult.

    def load_user_activities
      activities = user_property('Activities')&.property_value
      encounters = (activities&.split(',') || []).collect do |activity|
        # Re-map activities to encounters
        case activity
        when /ART adherence/i
          ART_ADHERENCE
        when /HIV clinic consultations/i
          HIV_CLINIC_CONSULTATION
        when /HIV first visits/i
          HIV_CLINIC_REGISTRATION
        when /HIV reception visits/i
          HIV_RECEPTION
        when /HIV staging visits/i
          HIV_STAGING
        when /Appointments/i
          APPOINTMENT
        when /Drug Dispensations/
          DISPENSING
        when /Prescriptions/i
          TREATMENT
        when /Vitals/i
          VITALS
        else
          Rails.logger.warn "Invalid ART activity in user properties: #{activity}"
        end
      end

      Set.new(encounters + [FAST_TRACK]) # Fast track is not selected as user activity
    end

    def next_state(current_state)
      ENCOUNTER_SM[current_state]
    end

    # Check if a relevant encounter of given type exists for given patient.
    #
    # NOTE: By `relevant` above we mean encounters that matter in deciding
    # what encounter the patient should go for in this present time.
    def encounter_exists?(type)
      # Vitals may be collected from a different program so don't check
      # for existence of an encounter rather check for the existence
      # of the actual vitals.
      return false if type.name == VITALS

      Encounter.where(type: type, patient: @patient, program: @program)\
               .where('encounter_datetime BETWEEN ? AND ?', *TimeUtils.day_bounds(@date))\
               .exists?
    end

    def valid_state?(state)
      return false if encounter_exists?(encounter_type(state)) || !art_activity_enabled?(state)

      (STATE_CONDITIONS[state] || []).reduce(true) do |status, condition|
        status && method(condition).call
      end
    end

    def art_activity_enabled?(state)
      return true if state == FAST_TRACK

      @activities.include?(state)
    end

    # Takes an ART encounter_type and remaps it to a corresponding HTN encounter
    def htn_transform(encounter_type)
      htn_activated = global_property('activate.htn.enhancement')&.property_value&.downcase == 'true'
      return encounter_type unless htn_activated

      htn_workflow.next_htn_encounter(@patient, encounter_type, @date)
    end

    # Checks if patient has checked in today
    #
    # Pre-condition for VITALS encounter
    def patient_checked_in?
      encounter_type = EncounterType.find_by name: HIV_RECEPTION
      encounter = Encounter.where(patient: @patient, type: encounter_type, program: @program)\
                           .where('encounter_datetime BETWEEN ? AND ?', *TimeUtils.day_bounds(@date))\
                           .order(encounter_datetime: :desc)\
                           .first
      
      return false if encounter.blank?
      #commented out the next line because emastercard was not working (will check 'why' later)
      #raise "Can't check if patient checked in due to missing HIV_RECEPTION" if encounter.nil?

      patient_present_concept = concept PATIENT_PRESENT
      yes_concept = concept 'YES'
      encounter.observations\
               .where(concept_id: patient_present_concept.concept_id,
                      value_coded: yes_concept.concept_id)\
               .exists?
    end

    # Check if patient is not registered
    def patient_not_registered?
      is_registered = Encounter.joins(:type).where(
        'encounter_type.name = ? AND encounter.patient_id = ? AND encounter.program_id = ?',
        HIV_CLINIC_REGISTRATION, @patient.patient_id, @program.program_id
      ).exists?

      !is_registered
    end

    # Check if patient is not a visiting patient
    def patient_not_visiting?
      patient_type_concept = concept('Type of patient')
      raise '"Type of patient" concept not found' unless patient_type_concept

      visiting_patient_concept = concept('External consultation')
      raise '"External consultation" concept not found' unless visiting_patient_concept

      is_visiting_patient = Observation.joins(:encounter).where(
        concept: patient_type_concept,
        person: @patient.person,
        value_coded: visiting_patient_concept.concept_id,
        encounter: { program_id: @program.program_id }
      ).where(
        'obs_datetime <= ?', TimeUtils.day_bounds(@date)[1]
      ).exists?

      !is_visiting_patient
    end

    # Check if patient is receiving any drugs today
    #
    # Pre-condition for TREATMENT encounter and onwards
    def patient_should_get_treatment?
      if referred_to_clinician?
        return false
      end

      prescribe_drugs_concept = concept('Prescribe drugs')
      no_concept = concept('No')
      start_time, end_time = TimeUtils.day_bounds(@date)
      !Observation.joins(:encounter).where(
        'concept_id = ? AND value_coded = ? AND person_id = ?
         AND program_id = ? AND obs_datetime BETWEEN ? AND ?',
        prescribe_drugs_concept.concept_id, no_concept.concept_id,
        @patient.patient_id, @program.program_id, start_time, end_time
      ).exists?
    end

    # Check if patient has got treatment.
    #
    # Pre-condition for DISPENSING encounter
    def patient_got_treatment?
      encounter_type = EncounterType.find_by name: TREATMENT
      encounter = Encounter.select('encounter_id').where(
        'patient_id = ? AND program_id = ? AND encounter_type = ?
         AND encounter_datetime BETWEEN ? AND ?',
        @patient.patient_id, @program.program_id, encounter_type.encounter_type_id,
        *TimeUtils.day_bounds(@date)
      ).order(encounter_datetime: :desc).first

      !encounter.nil? && encounter.orders.exists?
    end

    # Check if patient received A.R.T.s on previous visit
    def patient_received_art?
      # This code just looks suspect... It does the job and I understand
      # how it does what it does but I just don't trust it somehow.
      # Needs revision, this. Should be a correct or better way of
      # achieving the desired effect.
      arv_ids = Drug.arv_drugs.map(&:drug_id)
      arv_ids_placeholders = "(#{(['?'] * arv_ids.size).join(', ')})"
      Observation.joins(:encounter).where(
        "person_id = ? AND value_drug in #{arv_ids_placeholders} AND
         obs_datetime < ? AND encounter.program_id = ?",
        @patient.patient_id, *arv_ids, @date.to_date, @program.program_id
      ).exists?
    end

    # Checks if patient has not undergone staging before
    def patient_not_already_staged?
      encounter_type = EncounterType.find_by(name: 'HIV Staging')
      patient_staged = Encounter.where(
        'patient_id = ? AND program_id = ? AND encounter_type = ? AND encounter_datetime < ?',
        @patient.patient_id, @program.program_id, encounter_type.encounter_type_id,
        @date.to_date + 1.days
      ).exists?
      !patient_staged
    end

    def dispensing_complete?
      prescription_type = EncounterType.find_by(name: TREATMENT).encounter_type_id
      prescription = Encounter.find_by(encounter_type: prescription_type,
                                       patient_id: @patient.patient_id,
                                       program_id: @program.program_id)

      return false unless prescription

      complete = false

      prescription.orders.each do |order|
        complete = order.drug_order.amount_needed <= 0
        break unless complete
      end

      # TODO: Implement this regimen thingy below...
      # if complete
      #   dispension_completed = patient.set_received_regimen(encounter, prescription)
      # end
      complete
    end

    # Checks whether current patient is on a fast track visit
    def patient_not_on_fast_track?
      on_fast_track = Observation.joins(:encounter)\
                                 .where(concept: concept('Fast'), person_id: @patient.patient_id,
                                        encounter: { program_id: @program.program_id })\
                                 .where('obs_datetime <= ?', TimeUtils.day_bounds(@date)[1])\
                                 .order(obs_datetime: :desc)\
                                 .first
                                 &.value_coded

      no_concept = concept('No').concept_id
      on_fast_track = on_fast_track ? on_fast_track&.to_i : no_concept

      on_fast_track == no_concept
    end

    # Checks whether fast track visit has been completed
    #
    # This is meant to stop the workflow from restarting after completion of
    # a fast track visit.
    def patient_has_not_completed_fast_track_visit?
      return !@fast_track_completed if @fast_track_completed

      @fast_track_completed = Observation.joins(:encounter)\
                                         .where(concept: concept('Fast track visit'),
                                                person: @patient.person,
                                                value_coded: concept('Yes').concept_id,
                                                encounter: { program_id: @program.program_id })\
                                         .where('obs_datetime BETWEEN ? AND ?', *TimeUtils.day_bounds(@date))
                                         .order(obs_datetime: :desc)\
                                         .exists?

      !@fast_track_completed
    end

    # Check's whether fast track has been activated
    def fast_track_activated?
      global_property('enable.fast.track')&.property_value&.casecmp?('true')
    end

    def patient_does_not_have_height_and_weight?
      return true if patient_has_no_weight_today?

      return true if patient_has_no_height?

      patient_has_no_height_today? && patient_is_a_minor?
    end

    def patient_has_no_weight_today?
      concept_id = ConceptName.find_by_name('Weight').concept_id
      !Observation.where(concept_id: concept_id, person_id: @patient.id)\
                  .where('obs_datetime BETWEEN ? AND ?', *TimeUtils.day_bounds(@date))\
                  .exists?
    end

    def patient_has_no_height?
      concept_id = ConceptName.find_by_name('Height (cm)').concept_id
      !Observation.where(concept_id: concept_id, person_id: @patient.id)\
                  .where('obs_datetime < ?', TimeUtils.day_bounds(@date)[1])\
                  .exists?
    end

    def patient_has_no_height_today?
      concept_id = ConceptName.find_by_name('Height (cm)').concept_id
      !Observation.where(concept_id: concept_id, person_id: @patient.id)\
                  .where('obs_datetime BETWEEN ? AND ?', *TimeUtils.day_bounds(@date))\
                  .exists?
    end

    def patient_is_a_minor?
      @patient.age(today: @date) < MINOR_AGE_LIMIT
    end

    def referred_to_clinician?
      referred = Observation.joins(:encounter)\
                 .where(concept: concept('Refer to ART clinician'),
                        person: @patient.person,
                        encounter: { program_id: @program.program_id })\
                 .where('obs_datetime BETWEEN ? AND ?', *TimeUtils.day_bounds(@date))
                 .order(date_created: :desc, obs_datetime: :desc).first

     return false if referred.blank?
     return true if referred.value_coded == concept('Yes').concept_id
     return false
    end

    def htn_workflow
      HtnWorkflow.new
    end

    def load_hiv_program
      program('HIV Program')
    end
  end
end
