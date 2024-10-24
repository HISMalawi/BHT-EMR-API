# frozen_string_literal: true

module Api
  module V1
    class UsersController < ApplicationController
      DEFAULT_ROLENAME = 'clerk'
      include PasswordPolicy

      skip_before_action :authenticate, only: [:login]

      def index
        filters = params.permit(:role).to_hash.transform_keys(&:to_sym)
        render json: service.find_users(**filters)
      end

      def show
        render json: User.find(params[:id]), status: :ok
      end

      def create
        create_params = params.require(%i[username password given_name family_name roles])
        username, password, given_name, family_name, roles = create_params
        programs = params[:programs]

        return unless validate_roles(roles) & validate_username(username)

        # added this as a seperate return to prevent multiple redirects in case more than one validation fails
        return if programs && !validate_programs(programs)

        # added this as a seperate return to prevent multiple redirects in case more than one validation fails
        return if programs && !validate_programs_existance(programs)

        user = UserService.create_user(
          username:, password:, given_name:,
          family_name:, roles:, programs:
        )

        if user.errors.empty?
          render json: { user: }, status: :created
        else
          render json: { errors: user.errors }, status: :bad_request
        end
      rescue UserService::UserCreateError => e
        render json: { errors: e }, status: :internal_server_error
      end

      def update
        update_params = params.permit :password, :given_name, :family_name, :must_append_roles,
                                      roles: [], programs: []

        # Makes sure roles are an array if provided
        return unless validate_roles(update_params[:roles])

        user = UserService.update_user User.find(params[:id]), update_params
        if user.errors.empty?
          render json: user, status: :ok
        else
          render json: user.errors, status: :bad_request
        end
      end

      def login
        login_params, error = required_params required: %i[username password]
        return render json: login_params, status: :bad_request if error

        api_key = UserService.login(login_params[:username],
                                    login_params[:password])
        if api_key.nil?
          render json: { errors: ['Invalid user or password'] }, status: :unauthorized
        else
          render json: { authorization: api_key }
        end
      end

      def destroy
        if User.find(params[:id]).void('No reason provided')
          render status: :no_content
        else
          render json: { errors: ['Failed to void user'] }, status: :internal_server_error
        end
      end

      # GET
      def activate
        if UserService.activate_user(user)
          render json: { message: ['User activated'], user: }
        else
          render json: { errors: user.errors }
        end
      end

      # Deactivates user
      def deactivate
        if UserService.deactivate_user(user)
          render json: { message: ['User de-activated'], user: }
        else
          render json: { errors: user.errors }
        end
      end

      private

      def validate_roles(roles)
        if roles && !roles.respond_to?(:each)
          render json: ['`roles` must be an array'], status: :bad_request
          return false
        end

        true
      end

      def validate_username(username)
        if UserService.check_user(username)
          errors = ['User already exists']
          render json: { errors: }, status: :conflict
          return false
        end

        true
      end

      def user
        User.find(params[:id] || params[:user_id])
      end

      # validate user programs here
      def validate_programs(programs)
        if programs && !programs.respond_to?(:each)
          render json: ['`programs` must be an array'], status: :bad_request
          return false
        end

        true
      end

      # validate program
      def validate_programs_existance(programs)
        programs.each do |program_id|
          next if Program.find_by(program_id:)

          errors = ['All Programs must exists']
          render json: { errors: }, status: :conflict
          return false
        end
      end

      def service
        UserService
      end
    end
  end
end
