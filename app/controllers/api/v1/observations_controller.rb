require 'utils/remappable_hash'

class Api::V1::ObservationsController < ApplicationController
  # Retrieve specific observation
  #
  # GET /observations/:id
  def show
    render json: Observation.find(params[:id])
  end

  # Retrieve list of observations
  #
  # GET /observations
  #
  # Optional parameters
  #   person_id - Get observations belonging to this person
  #   concept_id - Get observations of this concept
  #   encounter_id - Get observations belonging to this encounter
  #   order_id - Retrieve observations of this order
  #   date_started - Observations must have this date_started
  #   date_stopped - Observations must have this date_stopped
  #
  # NOTE: When multiple parameters are specified they are
  #       AND-d together.
  def index
    filters, = required_params optional: %i[
      person_id concept_id encounter_id order_id date_started date_stopped
    ]

    if filters.empty?
      render json: paginate(Observation)
    else
      render json: paginate(Observation.where(filters))
    end
  end

  # Create new observation
  #
  # POST /observations
  #
  # Required parameters
  #   person_id - Person (not patient?) the observation is for
  #   encounter_id - The encounter this observation belongs to
  #   concept_id - The observation's concept
  #   value - This observations value
  #   value_type - Type of value above which must be one of boolean, coded,
  #                drug, datetime, numeric, modifier, text, complex.
  #   value_coded_name_id* - Only required if value_type above is coded
  #
  # Optional parameters
  #   order_id, comments
  def create
    encounter_id, plain_observations = params.require(%i[encounter_id observations])

    encounter = Encounter.find(encounter_id)
    observations = []

    plain_observations.each do |plain_obs|
      plain_obs.permit! # Oops...
      plain_obs[:obs_datetime] ||= Time.now
      plain_obs[:person_id] = encounter.patient.person.id
      observation = Observation.new(plain_obs)
      encounter.observations << observation
      observations << observation
    end

    unless encounter.save
      render json: encounter.errors, status: :bad_request
      return
    end

    render json: observations, status: :created
  end

  # Update existing observation
  #
  # PUT /observations/:id
  #
  # Optional parameters
  #   person_id - Person (not patient?) the observation is for
  #   encounter_id - The encounter this observation belongs to
  #   concept_id - The observation's concept
  #   value - This observations value
  #   value_type - Type of value above which must be one of boolean, coded,
  #                drug, datetime, numeric, modifier, text, complex.
  #   value_coded_name_id* - Only required if value_type above is coded
  #   order_id, comments
  def update
    update_params, errors = required_params required: %i[
      person_id concept_id encounter_id concept_id value value_type
      order_id comments
    ]
    return render json: update_params, status: :bad_request if errors

    return unless remap_value_to_typed_value update_params

    observation = Observation.find(params[:id])
    if observation.update(update_params)
      render json: observation, status: :created
    else
      render json: observation.errors, status: :bad_request
    end
  end

  # Delete existing observation
  #
  # DELETE /observation/:id
  def destroy
    observation = Observation.find(params[:id])
    if observation.void("Voided by #{User.current}")
      render status: :no_content
    else
      error = { errors: "Failed to delete observation ##{params[:id]}" }
      render json: error, status: :internal_server_error
    end
  end

  private

  # A map of value_types (see methods create and update) to their database
  # fields and dependent fields.
  # Map structure: value_type => [field_name, dependent_fields_list]
  OBS_VALUE_MAP = {
    'boolean' => [:value_boolean, []],
    'coded' => [:value_coded, [:value_coded_name_id]],
    'drug' => [:value_drug, []],
    'datetime' => [:value_datetime, []],
    'numeric' => [:value_numeric, []],
    'modifier' => [:value_modifier, []],
    'text' => [:value_text, []],
    'complex' => [:value_complex, []]
  }.freeze

  def obs_typed_value_field(param_name)
    OBS_VALUE_MAP.fetch param_name
  end

  # Remap plain `value` to typed `value_*`
  def remap_value_to_typed_value(params)
    typed_value, required_extras = OBS_VALUE_MAP[params[:value_type]]

    params.remap_field! :value, typed_value # Remap `value` to typed name
    params.delete :value_type # Remove value_type field

    return true if required_extras.empty?

    extra_params, errors = required_params required: required_extras
    if errors
      render json: extra_params, status: :bad_request
      return false
    end

    params.merge! extra_params
    true
  end
end
