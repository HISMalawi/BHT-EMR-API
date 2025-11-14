# frozen_string_literal: true

module NeonatalService
  ##
  # Handles neonatal program enrollment operations
  #
  # This engine is responsible for:
  # - Enrolling patients in the Neonatal program
  # - Creating enrollment encounters with observations
  # - Validating enrollment criteria
  # - Managing enrollment-related data
  class EnrollmentEngine
    include ModelUtils

    attr_reader :program, :patient, :date

    LOGGER = Rails.logger

    def initialize(patient:, program:, date: nil)
      @patient = patient
      @program = program
      @date = date || Date.today
    end

    ##
    # Enrolls patient in neonatal program
    #
    # @param enrollment_data [Hash] Enrollment parameters
    # @option enrollment_data [Date] :date_enrolled Date of enrollment
    # @option enrollment_data [Integer] :location_id Enrollment location
    # @option enrollment_data [Hash] :observations Enrollment observations
    #
    # @return [PatientProgram] Created patient program record
    def enroll(enrollment_data = {})
      validate_enrollment_eligibility!

      ActiveRecord::Base.transaction do
        patient_program = create_patient_program(enrollment_data)
        create_enrollment_encounter(enrollment_data)
        patient_program
      end
    rescue StandardError => e
      LOGGER.error("Failed to enroll patient #{@patient.id} in Neonatal program: #{e.message}")
      LOGGER.error(e.backtrace.join("\n"))
      raise e
    end

    ##
    # Checks if patient is already enrolled in neonatal program
    #
    # @return [Boolean]
    def enrolled?
      PatientProgram.where(
        patient_id: @patient.patient_id,
        program_id: @program.program_id
      ).where('date_completed IS NULL OR date_completed >= ?', @date)
        .exists?
    end

    ##
    # Gets active patient program for the patient
    #
    # @return [PatientProgram, nil]
    def patient_program
      @patient_program ||= PatientProgram.find_by(
        patient_id: @patient.patient_id,
        program_id: @program.program_id,
        date_completed: nil
      )
    end

    ##
    # Completes/exits patient from neonatal program
    #
    # @param exit_data [Hash] Exit parameters
    # @option exit_data [Date] :date_completed Exit date
    # @option exit_data [String] :outcome Exit outcome
    #
    # @return [PatientProgram]
    def exit_program(exit_data = {})
      raise 'Patient is not enrolled in Neonatal program' unless enrolled?

      patient_program.update!(
        date_completed: exit_data[:date_completed] || @date,
        outcome: exit_data[:outcome]
      )

      patient_program
    end

    ##
    # Retrieves enrollment data for the patient
    #
    # @return [Hash] Enrollment information
    def enrollment_data
      return {} unless enrolled?

      program = patient_program
      encounter = enrollment_encounter

      {
        patient_program_id: program.patient_program_id,
        date_enrolled: program.date_enrolled,
        location_id: program.location_id,
        enrollment_encounter_id: encounter&.encounter_id,
        enrollment_observations: enrollment_observations(encounter)
      }
    end

    ##
    # Gets the enrollment encounter for this patient
    #
    # @return [Encounter, nil]
    def enrollment_encounter
      @enrollment_encounter ||= Encounter.joins(:type)
                                         .where(
                                           'encounter_type.name = ? AND encounter.patient_id = ? AND encounter.program_id = ?',
                                           'NEONATAL ENROLLMENT',
                                           @patient.patient_id,
                                           @program.program_id
                                         )
                                         .order(encounter_datetime: :desc)
                                         .first
    end

    ##
    # Updates enrollment information
    #
    # @param updates [Hash] Updates to apply
    # @return [PatientProgram]
    def update_enrollment(updates = {})
      raise 'Patient is not enrolled in Neonatal program' unless enrolled?

      patient_program.update!(updates)
      patient_program
    end

    private

    ##
    # Validates that patient is eligible for enrollment
    def validate_enrollment_eligibility!
      raise 'Patient is already enrolled in Neonatal program' if enrolled?

      # Additional validation logic can be added here
      # e.g., age restrictions, etc.
      validate_patient_age if should_validate_age?
    end

    ##
    # Validates patient age for neonatal enrollment
    def validate_patient_age
      patient_age_in_days = (@date - @patient.birthdate).to_i
      max_age_in_days = 28 # Neonatal period is typically 0-28 days

      if patient_age_in_days > max_age_in_days
        LOGGER.warn("Patient #{@patient.patient_id} is #{patient_age_in_days} days old, exceeding neonatal period")
        # Uncomment to enforce strict age validation
        # raise "Patient is too old for neonatal enrollment (#{patient_age_in_days} days)"
      end
    end

    ##
    # Determines if age validation should be performed
    def should_validate_age?
      # Can be configured via global properties or settings
      GlobalProperty.find_by(property: 'neonatal.validate_age')&.property_value == 'true'
    end

    ##
    # Creates patient program record
    #
    # @param enrollment_data [Hash]
    # @return [PatientProgram]
    def create_patient_program(enrollment_data)
      PatientProgram.create!(
        patient_id: @patient.patient_id,
        program_id: @program.program_id,
        date_enrolled: enrollment_data[:date_enrolled] || @date,
        location_id: enrollment_data[:location_id] || Location.current.location_id,
        creator: User.current.user_id,
        date_created: Time.now
      )
    end

    ##
    # Creates enrollment encounter with observations
    #
    # @param enrollment_data [Hash]
    # @return [Encounter]
    def create_enrollment_encounter(enrollment_data)
      encounter = Encounter.create!(
        encounter_type: encounter_type('NEONATAL ENROLLMENT'),
        patient_id: @patient.patient_id,
        program_id: @program.program_id,
        encounter_datetime: enrollment_data[:encounter_datetime] || Time.now,
        location_id: enrollment_data[:location_id] || Location.current.location_id,
        provider_id: User.current.user_id,
        creator: User.current.user_id
      )

      # Create observations if provided
      create_enrollment_observations(encounter, enrollment_data[:observations]) if enrollment_data[:observations]

      encounter
    end

    ##
    # Creates observations for enrollment encounter
    #
    # @param encounter [Encounter]
    # @param observations [Array<Hash>]
    def create_enrollment_observations(encounter, observations)
      observations.each do |obs_data|
        create_observation(encounter, obs_data)
      end
    end

    ##
    # Creates a single observation
    #
    # @param encounter [Encounter]
    # @param obs_data [Hash]
    def create_observation(encounter, obs_data)
      concept_id = obs_data[:concept_id] || concept(obs_data[:concept_name])&.concept_id

      raise "Invalid concept: #{obs_data[:concept_name]}" unless concept_id

      obs_params = {
        concept_id: concept_id,
        person_id: @patient.person_id,
        encounter_id: encounter.encounter_id,
        obs_datetime: obs_data[:obs_datetime] || encounter.encounter_datetime,
        location_id: encounter.location_id,
        creator: User.current.user_id
      }.merge(observation_value_params(obs_data))

      observation = Observation.create!(obs_params)

      # Handle child observations (grouped observations)
      create_child_observations(observation, obs_data[:children]) if obs_data[:children]

      observation
    end

    ##
    # Extracts value parameters from observation data
    #
    # @param obs_data [Hash]
    # @return [Hash]
    def observation_value_params(obs_data)
      value_params = {}

      if obs_data[:value_coded]
        value_params[:value_coded] = obs_data[:value_coded]
        value_params[:value_coded_name_id] = obs_data[:value_coded_name_id]
      elsif obs_data[:value_numeric]
        value_params[:value_numeric] = obs_data[:value_numeric]
      elsif obs_data[:value_text]
        value_params[:value_text] = obs_data[:value_text]
      elsif obs_data[:value_datetime]
        value_params[:value_datetime] = obs_data[:value_datetime]
      elsif obs_data[:value_drug]
        value_params[:value_drug] = obs_data[:value_drug]
      end

      value_params
    end

    ##
    # Creates child observations for grouped observations
    #
    # @param parent_observation [Observation]
    # @param children [Array<Hash>]
    def create_child_observations(parent_observation, children)
      children.each do |child_data|
        child_data[:obs_group_id] = parent_observation.obs_id
        create_observation(parent_observation.encounter, child_data)
      end
    end

    ##
    # Retrieves enrollment observations
    #
    # @param encounter [Encounter, nil]
    # @return [Array<Hash>]
    def enrollment_observations(encounter)
      return [] unless encounter

      Observation.where(encounter_id: encounter.encounter_id, obs_group_id: nil)
                 .order(obs_datetime: :desc)
                 .map do |obs|
        {
          obs_id: obs.obs_id,
          concept_id: obs.concept_id,
          concept_name: obs.concept.concept_names.first&.name,
          value_coded: obs.value_coded,
          value_numeric: obs.value_numeric,
          value_text: obs.value_text,
          value_datetime: obs.value_datetime,
          obs_datetime: obs.obs_datetime,
          children: child_observations(obs)
        }
      end
    end

    ##
    # Retrieves child observations for a parent observation
    #
    # @param parent_obs [Observation]
    # @return [Array<Hash>]
    def child_observations(parent_obs)
      Observation.where(obs_group_id: parent_obs.obs_id)
                 .map do |obs|
        {
          obs_id: obs.obs_id,
          concept_id: obs.concept_id,
          concept_name: obs.concept.concept_names.first&.name,
          value_coded: obs.value_coded,
          value_numeric: obs.value_numeric,
          value_text: obs.value_text,
          value_datetime: obs.value_datetime,
          obs_datetime: obs.obs_datetime
        }
      end
    end
  end
end
