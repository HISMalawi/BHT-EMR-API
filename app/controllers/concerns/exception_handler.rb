# frozen_string_literal: true

module ExceptionHandler
  extend ActiveSupport::Concern

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
      errors = [e.message]
      errors << e.model_errors if e.model_errors
      render json: { errors: errors }, status: :bad_request
    end

    rescue_from UnprocessableEntityError do |e|
      render json: { errors: [e.message], entity: e.entity }, status: :unprocessable_entity
    end
  end
end
