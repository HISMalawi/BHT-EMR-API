# frozen_string_literal: true

class ObservationService
  attr_accessor :records

  def initialize
    @records = []
  end

  def create_observation(encounter, obs_parameters)
    proccess_obs_creation(encounter, obs_parameters)
    records
  rescue StandardError => e
    # log the error
    Rails.logger.error("Error creating observation: #{e.message}")
    raise e
  end

  private

  OBS_VALUE_FIELDS = %i[
    value_boolean value_numeric value_drug value_coded value_datetime
    value_text
  ].freeze

  def proccess_obs_creation(encounter, obs_parameters)
    ActiveRecord::Base.transaction do
      Rails.logger.debug("Creating observation: #{obs_parameters}")
      child_obs_parameters = obs_parameters.delete(:child)

      validate_presence_of_obs_value(obs_parameters)

      obs_parameters[:obs_datetime] = (
        TimeUtils.retro_timestamp(obs_parameters[:obs_datetime]) || encounter.encounter_datetime
      )
      obs_parameters[:person_id] = encounter.patient_id
      obs_parameters[:encounter_id] = encounter.id
      observation = Observation.create!(obs_parameters)
      validate_observation(observation)
      records << observation

      child_obs_parameters&.each do |child_obs|
        child_obs[:obs_group_id] = observation.obs_id
        proccess_obs_creation(encounter, child_obs)
      end
    end
  end

  def validate_presence_of_obs_value(obs_parameters)
    obs_value_exists = lambda do |obs_value_fields|
      return false if obs_value_fields.blank?

      return true unless obs_parameters[obs_value_fields[0]].blank?

      obs_value_exists.call(obs_value_fields[1..])
    end

    return true if obs_value_exists.call(OBS_VALUE_FIELDS)

    raise InvalidParameterError, "Empty observation: #{obs_parameters}"
  end

  # Raises an InvalidParameterError if the errors object of the observation
  # contains errors
  def validate_observation(observation)
    return true if observation.errors.empty?

    error = InvalidParameterError.new('Could not create/update observation')
    error.model_errors = observation.errors
    raise error
  end
end
