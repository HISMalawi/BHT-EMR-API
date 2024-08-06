# rubocop:disable Layout/LineLength, Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/ClassLength, Style/Documentation
# frozen_string_literal: true

require 'htn_workflow'

module ArtService
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
          next if seen_by_clinician?

          encounter_type = EncounterType.find_by(name: HIV_CLINIC_CONSULTATION)
          encounter_type.name = HIV_CLINIC_CONSULTATION_CLINICIAN
          return encounter_type if referred_to_clinician?

          next
        end

        return htn_transform(encounter_type) if valid_state?(state)
      end
      nil
    rescue StandardError => e
      LOGGER.error "Error while loading next encounter: #{e}"
      # stack trace
      LOGGER.error e.backtrace.join("\n")
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
    SYMPTOM_SCREENING = 'SYMPTOM SCREENING'
    AHD_SCREENING = 'AHD SCREENING'
    AHD_LAB_RESULTS = 'AHD LAB RESULTS'
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
      VITALS => SYMPTOM_SCREENING,
      SYMPTOM_SCREENING => HIV_STAGING,
      HIV_STAGING => AHD_SCREENING,
      AHD_SCREENING => AHD_LAB_RESULTS,
      AHD_LAB_RESULTS => HIV_CLINIC_CONSULTATION,
      HIV_CLINIC_CONSULTATION => ART_ADHERENCE,
      ART_ADHERENCE => HIV_CLINIC_CONSULTATION_CLINICIAN,
      HIV_CLINIC_CONSULTATION_CLINICIAN => TREATMENT,
      TREATMENT => FAST_TRACK,
      FAST_TRACK => DISPENSING,
      DISPENSING => APPOINTMENT,
      APPOINTMENT => END_STATE
    }.freeze

    STATE_CONDITIONS = {
      HIV_CLINIC_REGISTRATION => %i[patient_not_registered? patient_is_alive?
                                    patient_not_visiting?
                                    patient_not_coming_for_drug_refill?],
      HIV_RECEPTION => %i[patient_is_alive?],
      VITALS => %i[patient_is_alive?
                   patient_checked_in?
                   patient_not_on_fast_track?
                   patient_has_not_completed_fast_track_visit?
                   patient_does_not_have_height_and_weight?],
      SYMPTOM_SCREENING => %i[patient_is_alive? patient_not_on_fast_track?
                              patient_has_not_completed_fast_track_visit?
                              patient_not_coming_for_drug_refill?],
      SYMPTOM_SCREENING => %i[patient_is_alive? patient_not_on_fast_track?
                              patient_has_not_completed_fast_track_visit?
                              patient_not_coming_for_drug_refill?],
      HIV_STAGING => %i[patient_is_alive?
                        patient_not_already_staged_or_has_symptoms_screening?
                        patient_not_already_staged_or_has_symptoms_screening?
                        patient_has_not_completed_fast_track_visit?
                        patient_not_coming_for_drug_refill?],
      AHD_SCREENING => %i[continue_ahd_screening_accepted?
                          patient_is_alive? patient_not_on_fast_track?
                          patient_not_coming_for_drug_refill?
                          patient_has_not_completed_fast_track_visit?],
      AHD_LAB_RESULTS => %i[patient_is_alive? patient_not_on_fast_track? patient_not_coming_for_drug_refill? patient_has_not_completed_fast_track_visit? patient_results_not_available?],
      HIV_CLINIC_CONSULTATION => %i[patient_not_on_fast_track? patient_is_alive?
                                    patient_has_not_completed_fast_track_visit?],
      ART_ADHERENCE => %i[patient_received_art? patient_is_alive?
                          patient_has_not_completed_fast_track_visit?
                          patient_not_coming_for_drug_refill?],
      HIV_CLINIC_CONSULTATION_CLINICIAN => %i[patient_not_on_fast_track? patient_is_alive?
                                              patient_has_not_completed_fast_track_visit?
                                              patient_not_coming_for_drug_refill?],
      TREATMENT => %i[patient_should_get_treatment? patient_is_alive?
                      patient_has_not_completed_fast_track_visit?],
      FAST_TRACK => %i[fast_track_activated? patient_is_alive?
                       patient_got_treatment?
                       patient_not_on_fast_track?
                       patient_has_not_completed_fast_track_visit?
                       patient_not_coming_for_drug_refill?],
      DISPENSING => %i[patient_got_treatment? patient_is_alive?
                       patient_has_not_completed_fast_track_visit?],
      APPOINTMENT => %i[patient_got_treatment? patient_is_alive?
                        dispensing_complete?]
    }.freeze

    # Concepts
    PATIENT_PRESENT = 'Patient present'
    MINOR_AGE_LIMIT = 18 # Above this age, patient is considered an adult.

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
        when /Symptom screening/i
          SYMPTOM_SCREENING
        when /AHD screening/i
          AHD_SCREENING
        when /AHD lab results/i
          AHD_LAB_RESULTS
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

      Encounter.where(type:, patient: @patient, program: @program)\
               .where('encounter_datetime BETWEEN ? AND ?', *TimeUtils.day_bounds(@date))\
               .exists?
    end

    def valid_state?(state)
      return false if encounter_exists?(encounter_type(state)) || !art_activity_enabled?(state)

      (STATE_CONDITIONS[state] || []).all? { |condition| send(condition) }
    end

    def art_activity_enabled?(state)
      return true if [FAST_TRACK, AHD_LAB_RESULTS].include?(state)

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

      # commented out the next line because emastercard was not working (will check 'why' later)
      # raise "Can't check if patient checked in due to missing HIV_RECEPTION" if encounter.nil?

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

      is_visiting_patient = Observation.joins(:encounter)
                                       .where(concept: patient_type_concept,
                                              person: @patient.person,
                                              encounter: { program_id: @program.program_id })
                                       .where('obs_datetime <= ?', TimeUtils.day_bounds(@date)[1])
                                       .last
      return true if is_visiting_patient.blank?

      is_visiting_patient.value_coded != visiting_patient_concept.concept_id
    end

    # Check if patient is receiving any drugs today
    #
    # Pre-condition for TREATMENT encounter and onwards
    def patient_should_get_treatment?
      return false if referred_to_clinician? && !seen_by_clinician?

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

    def continue_ahd_screening_accepted?
      encounter_type = EncounterType.find_by(name: HIV_STAGING)
      continue_to_ahd_question = Observation.joins(:encounter)\
                                            .where(concept: concept('Continue with AHD'))
                                            .where(person: @patient.person)
                                            .where(encounter: { program_id: @program.program_id, encounter_type: })\
                                            .where('obs_datetime BETWEEN ? AND ?', *TimeUtils.day_bounds(@date))\
                                            .order(obs_datetime: :desc)\
                                            .first
      return false if continue_to_ahd_question.blank?

      continue_to_ahd_question&.value_coded == concept('Yes').concept_id
    end

    def patient_not_already_staged_or_has_symptoms_screening?
      return true if patient_not_already_staged?
      return true if patient_has_symptoms_screening?

      false
    end

    def patient_has_symptoms_screening?
      encounter_type = EncounterType.find_by(name: SYMPTOM_SCREENING)
      patient_screened = Encounter.where(
        'patient_id = ? AND program_id = ? AND encounter_type = ? AND encounter_datetime < ?',
        @patient.patient_id, @program.program_id, encounter_type.encounter_type_id,
        @date.to_date + 1.days
      )
      patient_screened.observations.any? do |observation|
        observation.value_coded == concept('Yes').concept_id
      end
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

    def patient_is_a_minor?
      @patient.age(today: @date) < MINOR_AGE_LIMIT
    end

    def patient_results_not_available?
      concept_id = ConceptName.find_by_name('Results available today').concept_id
      obs = Observation.where(concept_id:, person_id: @patient.id)\
                       .where('obs_datetime BETWEEN ? AND ?', *TimeUtils.day_bounds(@date))\
                       .where(value_coded: ConceptName.find_by_name('yes').concept_id)\
                       .exists?
      return false unless obs

      ## Now we need to check if all the AHD orders have results
      # Define the subquery for test_type.value_coded
      subquery = ConceptName.where(name: ['CSF Crag', 'Biopsy', 'Serum Crag', 'Urine Lam', 'GeneXpert', 'Culture & Sensitivity', 'TB Microscopic Exam', 'FASH']).select(:concept_id)

      # Main query
      orders = Order.joins("INNER JOIN obs test_type ON test_type.order_id = orders.order_id AND test_type.concept_id = 9737 AND test_type.value_coded IN (#{subquery.to_sql}) AND test_type.voided = 0")
                    .joins('LEFT JOIN obs test_result ON test_result.order_id = orders.order_id AND test_result.voided = 0 AND test_result.concept_id = 7363')
                    .where(order_type_id: 4, patient_id: @patient.id)
                    .where('orders.start_date BETWEEN ? AND ?', *TimeUtils.day_bounds(@date))
                    .group('orders.order_id')
                    .select('orders.start_date as visit_date, test_result.obs_datetime as entered_results')
                    .having('entered_results IS NULL')
      !orders.map { |order| order.entered_results.blank? }.count.zero?
    end

    def seen_by_clinician?
      # check if patient consultation was done by clinician
      Observation.joins(:encounter)\
                 .where(person: @patient.person,
                        encounter: { program_id: @program.program_id },
                        obs: { concept: concept('Medication orders'), # last observation for a consultation encounter
                               creator: [User.joins(:roles).where(role: { role: 'Clinician' }).pluck(:user_id)].flatten }).where('obs_datetime BETWEEN ? AND ?', *TimeUtils.day_bounds(@date))\
                 .exists?
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

      false
    end

    def patient_not_coming_for_drug_refill?
      find_visit_type_observation&.value_coded != ConceptName.find_by!(name: Concept::DRUG_REFILL).concept_id
    end

    def find_visit_type_observation
      Observation.joins(:encounter)
                 .where(concept: ConceptName.where(name: Concept::PATIENT_TYPE).select(:concept_id),
                        person: @patient.person,
                        encounter: { program_id: @program.program_id })
                 .where('obs_datetime < DATE(?) + INTERVAL 1 DAY', @date)
                 .order(obs_datetime: :desc)
                 .first
    end

    # Checks whether the patient is alive and avoids trigger next encounter if they a state of died
    def patient_is_alive?
      program = PatientProgram.where(patient_id: @patient.id, program_id: @program.program_id)&.first
      return true if program.blank?

      current_state = PatientState.where(patient_program: program, state: 3).where('start_date <= ?', @date)
      !current_state.present?
    end

    def htn_workflow
      HtnWorkflow.new
    end

    def load_hiv_program
      program('HIV Program')
    end
  end
end

# rubocop:enable Layout/LineLength, Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/ClassLength, Style/Documentation
