# frozen_string_literal: true

# This controller handles creation and authentication of LIMS User
module Lab
  class UsersController < ::ApplicationController
    skip_before_action :authenticate
    # create a LIMS User that will be responsible for sending lab results
    def create
      user_params = params.permit(:username, :password)
      service.create_lims_user(username: user_params['username'], password: user_params['password'])
      render json: { message: 'User successfully created' }, status: 200
    end

    # authenticate the lims user
    def login
      user_params = params.permit(:username, :password)
      result = service.authenticate_user(username: user_params['username'], password: user_params['password'],
                                         user_agent: request.user_agent, request_ip: request.remote_ip)
      if result.present?
        render json: result, status: 200
      else
        render json: { message: 'Invalid Credentials Provided' }, status: 401
      end
    end

    private

    def service
      Lab::UserService
    end
  end
end
