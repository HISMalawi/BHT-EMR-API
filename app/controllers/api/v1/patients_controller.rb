# frozen_string_literal: true

require 'dde_client'

class Api::V1::PatientsController < ApplicationController
  before_action :load_dde_client

  def show
    response, = @dde_client.post 'search_by_npid', {npid: params[:id]}
    render json: response
  end

  def get
    patient = @dde_service.find_patient(params[:id])
    unless patient
      errors = ["Patient ##{params[:id]} not found"]
      render json: { errors: errors }, status: :bad_request
      return
    end
    render json: patient
  end

  def create
    # patient = @dde_service.create_patient()
  end

  private

  DDE_CONFIG_PATH = 'config/application.yml'

  def load_dde_client
    @dde_client = DDEClient.new

    logger.debug 'Searching for a stored DDE connection'
    connection = Rails.application.config.dde_connection
    if connection
      logger.debug "Stored DDE connection found: #{connection}"
      @dde_client.connect connection: connection
    else
      logger.debug 'No stored DDE connection found... Loading config...'
      app_config = YAML.load_file DDE_CONFIG_PATH
      Rails.application.config.dde_connection = @dde_client.connect(
        config: {
          username: app_config['dde_username'],
          password: app_config['dde_password'],
          base_url: app_config['dde_url']
        }
      )
    end
  end
end
