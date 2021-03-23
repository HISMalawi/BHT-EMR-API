# frozen_string_literal: true

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
    filters = params.permit(%i[person_id concept_id encounter_id order_id
                               value_coded value_datetime value_numeric
                               accession_number value_text])

    query = filters.empty? ? Observation : Observation.where(filters)

    filter_period = index_filter_period
    query = query.where('obs_datetime BETWEEN ? AND ?', *filter_period) if filter_period

    query = query.order(obs_datetime: :desc)

    render json: paginate(query)
  end

  # Create new observation
  #
  # POST /observations
  #
  # Required parameters
  #   person_id - Person (not patient?) the observation is for
  #   encounter_id - The encounter this observation belongs to
  #   concept_id - The observation's concept
  #   value_* - This observations value
  #
  # Optional parameters
  #   order_id, comments
  def create
    encounter_id, obs_archetypes = params.require %i[encounter_id observations]

    encounter = Encounter.find(encounter_id)

    observations = obs_archetypes.collect do |archetype|
      obs, _child_obs = service.create_observation(encounter, archetype.permit!)
      obs
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
    update_params = params.permit! # FIX-ME: This is highly unsafe

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


  def index_filter_period
    period = nil

    if params.include?(:start_date) || params.include?(:end_date)
      start_date, end_date = params.require(%i[start_date end_date])
      period = [start_date.to_time, end_date.to_time + (24.hours - 1.second)]
    elsif params[:obs_datetime]
      period = TimeUtils.day_bounds(params[:obs_datetime])
    end

    period
  end

  def service
    ObservationService
  end
end
