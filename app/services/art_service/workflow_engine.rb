# frozen_string_literal: true

module ARTService
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
    HIV_CLINIC_REGISTRATION = 'HIV CLINIC REGISTRATION'
    HIV_RECEPTION = 'HIV RECEPTION'
    VITALS = 'VITALS'
    HIV_STAGING = 'HIV STAGING'
    HIV_CLINIC_CONSULTATION = 'HIV CLINIC CONSULTATION'
    ART_ADHERENCE = 'ART ADHERENCE'
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
      ART_ADHERENCE => TREATMENT,
      TREATMENT => FAST_TRACK,
      FAST_TRACK => DISPENSING,
      DISPENSING => APPOINTMENT,
      APPOINTMENT => END_STATE
    }.freeze

    STATE_CONDITIONS = {
      HIV_CLINIC_REGISTRATION => %i[patient_not_registered? patient_not_visiting?],
      VITALS => %i[patient_checked_in?],
      HIV_STAGING => %i[patient_not_already_staged?],
      ART_ADHERENCE => %i[patient_received_art?],
      TREATMENT => %i[patient_should_get_treatment?],
      FAST_TRACK => %i[patient_got_treatment? assess_for_fast_track?],
      DISPENSING => %i[patient_got_treatment?],
      APPOINTMENT => %i[patient_got_treatment? dispensing_complete?]
    }.freeze

    # Concepts
    PATIENT_PRESENT = 'Patient present'

    def next_state(current_state)
      ENCOUNTER_SM[current_state]
    end

    # Check if a relevant encounter of given type exists for given patient.
    #
    # NOTE: By `relevant` above we mean encounters that matter in deciding
    # what encounter the patient should go for in this present time.
    def encounter_exists?(type)
      # HACK: Pretend Fast Track does not exist
      return false if type.encounter_type_id == encounter_type(FAST_TRACK).encounter_type_id

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
      encounter_type = EncounterType.find_by name: HIV_RECEPTION
      encounter = Encounter.where(
        'patient_id = ? AND encounter_type = ? AND DATE(encounter_datetime) = DATE(?)',
        @patient.patient_id, encounter_type.encounter_type_id, @date
      ).order(encounter_datetime: :desc).first
      raise "Can't check if patient checked in due to missing HIV_RECEPTION" if encounter.nil?
      patient_present_concept = concept PATIENT_PRESENT
      yes_concept = concept 'YES'
      encounter.observations.exists? concept_id: patient_present_concept.concept_id,
                                     value_coded: yes_concept.concept_id
    end

    # Check if patient is not registered
    def patient_not_registered?
      is_registered = Encounter.joins(:type).where(
        'encounter_type.name = ? AND encounter.patient_id = ?',
        HIV_CLINIC_REGISTRATION,
        @patient.patient_id
      ).exists?

      !is_registered
    end

    # Check if patient is not a visiting patient
    def patient_not_visiting?
      patient_type_concept = concept('Type of patient')
      raise '"Type of patient" concept not found' unless patient_type_concept

      visiting_patient_concept = concept('Visiting patient')
      raise '"Visiting patient" concept not found' unless visiting_patient_concept

      is_visiting_patient = Observation.where(
        concept: patient_type_concept,
        person: @patient.person,
        value_coded: visiting_patient_concept.concept_id
      ).exists?

      !is_visiting_patient
    end

    # Check if patient is receiving any drugs today
    #
    # Pre-condition for TREATMENT encounter and onwards
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

    # Check if patient has got treatment.
    #
    # Pre-condition for DISPENSING encounter
    def patient_got_treatment?
      encounter_type = EncounterType.find_by name: TREATMENT
      encounter = Encounter.select('encounter_id').where(
        'patient_id = ? AND encounter_type = ? AND DATE(encounter_datetime) = DATE(?)',
        @patient.patient_id, encounter_type.encounter_type_id, @date
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
      Observation.where(
        "person_id = ? AND value_drug in #{arv_ids_placeholders} AND
         obs_datetime < ?",
        @patient.patient_id, *arv_ids, @date
      ).exists?
    end

    # Checks if patient has not undergone staging before
    def patient_not_already_staged?
      encounter_type = EncounterType.find_by name: 'HIV Staging'
      patient_staged = Encounter.where(
        'patient_id = ? AND encounter_type = ? AND encounter_datetime < ?',
        @patient.patient_id, encounter_type.encounter_type_id, @date.to_date + 1.days
      ).exists?
      !patient_staged
    end

    def dispensing_complete?
      prescription_type = EncounterType.find_by(name: TREATMENT).encounter_type_id
      prescription = Encounter.find_by(encounter_type: prescription_type,
                                       patient_id: @patient.patient_id)

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

    def assess_for_fast_track?
      false # Disable fast track until DHA approves

      # encounter = Encounter.where(encounter_type: encounter_type(FAST_TRACK),
      #                             patient: @patient)\
      #                      .where('encounter_datetime BETWEEN ? AND ?', *TimeUtils.day_bounds(@date))
      #                      .order(encounter_datetime: :desc)
      #                      .first

      # # HACK: In an ideal situation we should be returning true here to
      # # trigger creation of a new encounter on client side however
      # # client-side at this point normally already has an encounter
      # # created with 'assess for fast track either set to yes or no'
      # return false unless encounter

      # assess_for_fast_track_concept = concept('Assess for fast track?')

      # # Should we assess fast track?
      # assess_fast_track = encounter.observations.where(
      #   concept: assess_for_fast_track_concept,
      #   value_coded: concept('Yes').concept_id
      # ).exists?

      # return false unless assess_fast_track

      # # Have we already assessed fast track?
      # # We check for this condiition by looking for any observations other
      # # 'Assess for fast track' which we are assuming are
      # fast_track_assessed = encounter.observations.where.not(
      #   concept: assess_for_fast_track_concept
      # ).exists?

      # !fast_track_assessed
    end
  end
end
