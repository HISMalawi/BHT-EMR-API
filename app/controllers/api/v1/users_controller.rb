# frozen_string_literal: true

module Api
  module V1
    class UsersController < ApplicationController

      
      DEFAULT_ROLENAME = 'clerk'
      include PasswordPolicy

      skip_before_action :authenticate, only: %i[login reset_password]

      def index
        filters = params.permit(:role, :search_string).to_hash.transform_keys(&:to_sym)
        query = service.find_users(**filters) 

        render json: {
          count: query[1],
          results: paginate(query[0])
        }, status: :ok
      end

      def show
        render json: User.find(params[:id]), status: :ok
      end

      def update_username
        update_params = params.require(%i[new_username])
        new_username,  = update_params
        id = user.user_id
        return unless validate_username(new_username)
        user =  UserService.update_username User.find(id), new_username
        render json: { message: ['username updated successfully'], user: }
      end

      def create
        create_params = params.require(%i[username password given_name family_name roles location_id])
        username, password, given_name, family_name, roles, location_id = create_params
        programs = params[:programs]
        villages = params[:villages]
        phone = params[:phone]

        return unless validate_roles(roles) & validate_username(username)

        # added this as a seperate return to prevent multiple redirects in case more than one validation fails
        return if programs && !validate_programs(programs)

        # added this as a seperate return to prevent multiple redirects in case more than one validation fails
        return if programs && !validate_programs_existance(programs)

        user = UserService.create_user(
          username:, password:, given_name:,
          family_name:, roles:, programs:, location_id:, villages:, phone:
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
        update_params = params.permit :password, :given_name, :family_name, :must_append_roles, :location_id,
                                      roles: [], programs: []

        # Makes sure roles are an array if provided
        return unless validate_roles(update_params[:roles])

        user = UserService.update_user User.find(params[:id]), update_params
        
        if user.errors.empty?
          update_last_password_property(user.id, update_params[:password])
          render json: user, status: :ok
        else
          render json: user.errors, status: :bad_request
        end
      end

      def reset_password
        code = params[:code]

        render json: { authorization: UserService.reset_password(code:) },
                status: :ok
      end

      def login
        login_params, error = required_params required: %i[username password]
        return render json: login_params, status: :bad_request if error

        api_key = UserService.login(login_params[:username], login_params[:password])
        
        if api_key.nil?
          render json: { errors: ['Invalid user or password'] }, status: :unauthorized
        else
          user = User.find_by(username: login_params[:username])
          
          if user
            # Check if this is first time login BEFORE updating
            # Check both existence and that the value is not blank
            existing_property = UserProperty.find_by(
              property: 'last_login_time',
              user_id: user.user_id
            )
            
            is_first_time = existing_property.nil? || existing_property.property_value.blank?
            
            # Update or create the last_login_time property
            property = UserProperty.find_or_initialize_by(
              property: 'last_login_time',
              user_id: user.user_id
            )
            
            property.property_value = Time.current.iso8601
            property.save
            
            render json: { 
              authorization: api_key,
              first_time_login: is_first_time,
              password_needs_update: password_needs_update?(user.user_id)
            }
          else
            render json: { authorization: api_key }
          end
        end
      end

      def check_first_time_login
        user_id = params[:user_id] || User.current.user_id
        
        last_login_property = UserProperty.find_by(
          property: 'last_login_time',
          user_id: user_id
        )
        
        # Check both existence and that the value is not blank
        is_first_time = last_login_property.nil? || last_login_property.property_value.blank?
        
        render json: {
          user_id: user_id,
          first_time_login: is_first_time,
          has_logged_in_before: !is_first_time,
          last_login_time: last_login_property&.property_value,
          message: is_first_time ? 'User has never logged in before' : 'User has logged in before'
        }, status: :ok
      rescue StandardError => e
        render json: { errors: [e.message] }, status: :internal_server_error
      end

      def clear_last_login_time
        user_id = params[:user_id] || User.current.user_id

        last_login_property = UserProperty.find_by(
          property: 'last_login_time',
          user_id: user_id
        )
        
        if last_login_property
          last_login_property.destroy
          render json: { message: 'Last login time cleared successfully' }, status: :ok
        else
          render json: { message: 'No last login time found to clear' }, status: :ok
        end
      rescue StandardError => e
        render json: { errors: [e.message] }, status: :internal_server_error
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

      def update_user_villages
        update_params = params.permit user_village_ids: []
        user_villages = UserService.update_user_villages(user, update_params[:user_village_ids])
        render json: { villages: user_villages }, status: :ok
      rescue => e
        render json: { errors: [e.message] }, status: :internal_server_error
      end

      def get_user_villages
        villages = UserService.get_user_villages(user).where(retired: 0)
        render json: { villages: villages }, status: :ok
      rescue StandardError => e
        render json: { errors: [e.message] }, status: :internal_server_error
      end

      def check_username_exist
        username_param = params.permit(:username)
        if username_param[:username].blank?
          render json: { errors: ['Username parameter is required'] }, status: :bad_request
          return
        end
        
        exists = UserService.check_user(username_param[:username])
        render json: { exists: exists }, status: :ok
      rescue StandardError => e
        render json: { errors: [e.message] }, status: :internal_server_error
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

      def update_last_password_property(user_id, password)
        return unless password.present?
        
        property = UserProperty.find_or_initialize_by(
          property: 'last_password_updated',
          user_id: user_id
        )
        
        property.property_value = Time.current.to_s
        property.save
      end

      def password_needs_update?(user_id)
        last_password_property = UserProperty.find_by(
          property: 'last_password_updated',
          user_id: user_id
        )
        
        # Return false if no property exists or property_value is blank
        return false if last_password_property.nil? || last_password_property.property_value.blank?
        
        # Parse the timestamp and check if 90 days have elapsed
        last_updated = Time.parse(last_password_property.property_value)
        Time.current >= last_updated + 90.days
      rescue ArgumentError
        # Return false if timestamp can't be parsed
        false
      end

      def service
        UserService
      end
    end
  end
end
