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

        LOGGER.debug "Checking existence of #{state} encounter"
        next if encounter_exists?(encounter_type)

        LOGGER.debug "Checking eligibility of #{state} encounter"

        case state
        when HIV_CLINIC_REGISTRATION
          return encounter_type unless patient_registered?
        when VITALS
          return encounter_type if patient_checked_in?
        when ART_ADHERENCE
          return encounter_type if patient_received_art?
        when DISPENSING
          return encounter_type if patient_got_treatment?
        when APPOINTMENT
          return encounter_type if dispensing_complete?
        else
          return encounter_type
        end
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
      TREATMENT => DISPENSING,
      DISPENSING => APPOINTMENT,
      APPOINTMENT => END_STATE
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
    def encounter_exists?(encounter_type)
      Encounter.where(
        'encounter_type = ? AND patient_id = ?
         AND DATE(encounter_datetime) = DATE(?)',
        encounter_type.encounter_type_id,
        @patient.patient_id,
        @date
      ).exists?
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

    def patient_registered?
      Encounter.joins(:type).where(
        'encounter_type.name = ? AND encounter.patient_id = ?',
        HIV_CLINIC_REGISTRATION,
        @patient.patient_id
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
      raise "Can't check if patient got treatment due to missing TREATMENT encounter" if encounter.nil?
      encounter.orders.exists?
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
  end
end
