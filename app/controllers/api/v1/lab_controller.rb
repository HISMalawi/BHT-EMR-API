# frozen_string_literal: true

class Api::V1::LabController < ApplicationController
  # Dispatches any requests received to matching methods in the bound service
  #
  # Example:
  #   `GET programs/1/lab/random?foo=bar` -> ARTService::Lab.new().dispatch(params)
  def dispatch_request
    logger.info(params)

    logger.info([service, service.methods])
    method = service.method(params[:resource].to_sym)
    unless method
      raise NotFoundError, "Resouce `#{params[:resource]}` not found in #{service.class}"
    end

    render json: method.call(params)
  end

  private

  def service
    LabService.new(program).load_engine
  end

  def program
    Program.find(params[:program_id])
  end
end
