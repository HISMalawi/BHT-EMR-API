# frozen_string_literal: true

require 'require_params'

class ApplicationController < ActionController::API
  before_action :authenticate

  protected

  include RequireParams

  def authenticate
    authentication_token = request.headers['Authorization']
    unless authentication_token
      errors = ['Authorization token required']
      render json: { errors: errors }, status: :unauthorized
      return false
    end

    user = UserService.authenticate authentication_token
    unless user
      errors = ['Invalid or expired authentication token']
      render json: { errors: errors }, status: :unauthorized
      return false
    end

    User.current = user
    true
  end
end
