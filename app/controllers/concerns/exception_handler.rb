# frozen_string_literal: true

module ExceptionHandler
  extend ActiveSupport::Concern

  def log_exception(exception)
    stack_trace = exception.backtrace.join("\n")
    Rails.logger.error("\n\n\033[1m#{exception.class} - #{exception.message}\033[0m\n#{stack_trace}")
  end

  included do
    # rescues are performed in a LIFO manner thus base classes must be
    # declared early.
    rescue_from ApplicationError do |e|
      render json: { errors: [e.message] }, status: :internal_server_error
    end

    rescue_from NotFoundError do |e|
      render json: { errors: [e.message] }, status: :not_found
    end

    rescue_from InvalidParameterError do |e|
      log_exception(e)
      errors = [e.message]
      errors << e.model_errors if e.model_errors
      render json: { errors: errors }, status: :bad_request
    end

    rescue_from UnprocessableEntityError do |e|
      render json: { errors: [e.message], entity: e.entity }, status: :unprocessable_entity
    end

    rescue_from RestClient::Exception, Errno::ECONNREFUSED do |e|
      log_exception(e)

      if e.respond_to?(:response)
        Rails.logger.error("\n\n\033[1mExternal service response:\033[0m\n#{e.response.body}")
      end

      render json: { errors: ["Failed to communicate with external service: #{e.message}"] },
             status: :bad_gateway
    end

    rescue_from LimsError do |e|
      log_exception(e)
      render json: { errors: ["Failed to communicate with LIMS: #{e.message}"] },
             status: :bad_gateway
    end

    rescue_from DDEService::DDEError do |e|
      log_exception(e)
      render json: { errors: ["Failed to communicate with DDE: #{e.message}"] },
             status: :bad_gateway
    end
  end
end
