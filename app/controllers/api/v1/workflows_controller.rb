# frozen_string_literal: true

class Api::V1::WorkflowsController < ApplicationController
  # Retrieves patient's next encounter given previous encounters
  # and enrolled program
  def next_encounter
    program_id = params[:program_id]
    patient_id = params[:patient_id]

    unless PatientProgram.exists?(patient_id: patient_id, program_id: program_id)
      render json: "Patient ##{patient_id} not enrolled in program ##{program_id}",
             status: :bad_request
      return
    end

    encounter = current_encounter patient_id

    if encounter
      render json: encounter
    else
      render status: :no_content
    end
  end

  private

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

  def current_encounter(patient_id)
    state = INITIAL_STATE
    loop do
      state = next_state state
      break if state == END_STATE

      logger.debug "Loading encounter type: #{state}"
      encounter_type = EncounterType.find_by(name: state)

      logger.debug "Checking existence of #{state} encounter"
      next if encounter_exists?(state, encounter_type, patient_id)

      logger.debug "Checking eligibility of #{state} encounter"

      case state
      when VITALS
        return encounter_type if patient_checked_in?(patient_id)
      when ART_ADHERENCE
        return encounter_type if patient_received_art?(patient_id)
      when DISPENSING
        return encounter_type if patient_got_treatment?(patient_id)
      when APPOINTMENT
        return encounter_type if dispensing_complete?(patient_id)
      else
        return encounter_type
      end
    end

    nil
  end

  def next_state(current_state)
    ENCOUNTER_SM[current_state]
  end

  # Check if a relevant encounter of given type exists for given patient.
  #
  # NOTE: By `relevant` above we mean encounters that matter in deciding
  # what encounter the patient should go for in this present time.
  def encounter_exists?(state, encounter_type, patient_id)
    if state == HIV_CLINIC_REGISTRATION
      search_params = [
        'encounter_type = ? AND patient_id = ?', encounter_type.id, patient_id
      ]
    else
      # Interested in today's encounters only
      search_params = [
        'encounter_type = ? AND patient_id = ? AND DATE(encounter_datetime) = DATE(?)',
        encounter_type.encounter_type_id, patient_id, Time.now
      ]
    end

    Encounter.where(*search_params).exists?
  end

  # Checks if patient has checked in today
  #
  # Pre-condition for VITALS encounter
  def patient_checked_in?(patient_id)
    encounter_type = EncounterType.select('encounter_type_id').find_by(name: HIV_RECEPTION)
    encounter = Encounter.select('encounter_id').where(
      patient_id: patient_id, encounter_type: encounter_type.encounter_type_id
    ).order(:encounter_datetime).last
    raise "Can't check if patient checked in due to missing HIV_RECEPTION encounter" if encounter.nil?
    obs_concept = concept PATIENT_PRESENT
    encounter.observations.exists?(concept_id: obs_concept.id)
  end

  # Check if patient has got treatment.
  #
  # Pre-condition for DISPENSING encounter
  def patient_got_treatment?(patient_id)
    encounter_type = EncounterType.select('encounter_type_id').find_by(name: TREATMENT)
    encounter = Encounter.select('encounter_id').find_by(
      patient_id: patient_id, encounter_type: encounter_type.encounter_type_id
    )
    raise "Can't check if patient got treatment due to missing TREATMENT encounter" if encounter.nil?
    obs_concept = concept TREATMENT
    encounter.observations.exists?(concept_id: obs_concept.id)
  end

  # Check if patient received A.R.T.s on previous visit
  def patient_received_art?(patient_id)
    # This code just looks suspect... It does the job and I understand
    # how it does what it does but I just don't trust it somehow.
    # Needs revision, this. Should be a correct or better way of
    # achieving the desired effect.
    arv_ids = Drug.arv_drugs.map(&:drug_id)
    arv_ids_placeholders = "(#{(['?'] * arv_ids.size).join(', ')})"
    Observation.where(
      "person_id = ? AND value_drug in #{arv_ids_placeholders}", patient_id,
      *arv_ids
    ).exists?
  end

  def dispensing_complete?(patient_id)
    prescription_type = EncounterType.find_by(name: TREATMENT).encounter_type_id
    prescription = Encounter.find_by(encounter_type: prescription_type,
                                     patient_id: patient_id)

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

  # Retrieve concept by its name
  #
  # Parameters:
  #  name - A string repr of the concept name
  def concept(name)
    ConceptName.find_by(name: name).concept
  end
end
