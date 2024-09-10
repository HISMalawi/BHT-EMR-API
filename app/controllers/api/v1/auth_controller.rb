# frozen_string_literal: true

module Api
    module V1
      # This is the AuthController class
      class AuthController < ApplicationController
        before_action :authorize_request, only: %i[login]
  
        def health
          tag = `git describe`.chomp
          render json: { 'System version': tag }
        rescue StandardError
          render json: { status: 'Head not set. Please run: git describe --tags > HEAD in BHT-EMR-API root folder.',
                         error: 'No Head containing tag description found' }
        end
  
        def login
          @user = User.find_by(username: params[:username])
          if @user&.authenticate(params[:password])
            key_supplement = browser.name + browser.version
            token = Utils::JsonWebToken.encode(payload: { user_id: @user.uuid }, key_supplement:, exp: 4.hours.from_now)
            render json: { user: @user, jwt: token }, status: :accepted
          else
            render json: { message: 'Invalid username or password' }, status: :unauthorized
          end
        end
      end
    end
  end