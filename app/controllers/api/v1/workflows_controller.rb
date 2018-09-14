# frozen_string_literal: true

class Api::V1::WorkflowsController < ApplicationController
  # Retrieves patient's next encounter given previous encounters
  # and enrolled program
  def next_encounter
    date = params.permit(:date)[:date] || Time.now

    program_id = params[:program_id]
    patient_id = params[:patient_id]

    # if patient has encounter HIV CLINIC REGISTRATION:
    #   if patient has encounter HIV RECEPTION:
    #     if patient present in HIV RECEPTION obs:
    #       if patient has VITALS encounter:
    #          if patient has encounter HIV STAGING:
    # else

    unless PatientProgram.exists?(patient_id: patient_id, program_id: program_id)
      render json: "Patient ##{patient_id} not enrolled in program ##{program_id}",
             status: :bad_request
      return
    end

    state = INITIAL_STATE
    while state != END_STATE
      state = next_state state

      logger.debug "Current state is: #{state}"
      render(status: :no_content) && return if state == END_STATE

      encounter_type = EncounterType.find_by(name: state)

      next if encounter_exists?(state, encounter_type, patient_id)

      logger.debug "Encounter type (#{encounter_type.name}) not found"

      case state
      when VITALS
        render json: encounter_type && return if patient_checked_in? patient_id
      when DISPENSING
        render json: encounter_type && return if patient_got_treatment? patient_id
      when APPOINTMENT
        # render json: encounter_type && return if DISPENSING is complete
        raise 'Dont know how to handle APPOINTMENT'
      else
        render(json: encounter_type) && return
      end
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
        encounter_type.id, patient_id, Time.now
      ]
    end

    Encounter.exists?(search_params)
  end

  # Checks if patient has checked in today
  #
  # Pre-condition for VITALS encounter
  def patient_checked_in?(patient_id)
    encounter_type = EncounterType.select('encounter_type_id').find_by(name: HIV_RECEPTION)
    encounter = Encounter.select('encounter_id').find_by(
      patient_id: patient_id, encounter_type: encounter_type.encounter_type_id
    )
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

  def dispensing_complete?(patient_id)
    false
  end

  # Retrieve concept by its name
  #
  # Parameters:
  #  name - A string repr of the concept name
  def concept(name)
    ConceptName.find_by(name: name).concept
  end
end
