# frozen_string_literal: true

module ExceptionHandler
  extend ActiveSupport::Concern

  included do
    rescue_from NotFoundError do |e|
      render json: { errors: [e.message] }, status: :not_found
    end

    rescue_from ApplicationError do |e|
      render json: { errors: [e.message] }, status: :internal_server_error
    end
  end
end
