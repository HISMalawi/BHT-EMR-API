require 'user_service'

class Api::V1::UserController < ApplicationController
  DEFAULT_ROLENAME = 'clerk'

  before_action :check_if_token_valid
  skip_before_action :check_if_token_valid, only: [:authenticate_user]

  def index
    results = []

    User.all.each{|user|
      person = Person.find(user.person_id) rescue next
      name   = PersonName.where(person_id: user.person_id).last
      next if name.blank?

      results << {
          username:  user.username,
          first_name: name.given_name,
          last_lame: name.family_name,
          gender:    person.gender,
          birthdate: person.birthdate,
          role: ""
      }
    }

    if !results.blank?
      render json: {
          status: 200,
          error: false,
          message: 'users found',
          data: results
        }
    else
      render json: {
          status: 401,
          error: true,
          message: 'users notfound',
          data: {}
      }
    end
  end

  def get_user
    user = User.where(username: params[:username]).first
    person = Person.find(user.person_id)
    name   = PersonName.where(person_id: user.person_id).last


    if !user.blank? && !person.blank? && !name.blank?
      render json: {
          status: 200,
          error: false,
          message: 'user found',
          data: {
              username:  user.username,
              first_name: name.given_name,
              last_lame: name.family_name,
              gender:    person.gender,
              birthdate: person.birthdate,
              role: ""
          }
      }
    else
      render json: {
          status: 401,
          error: true,
          message: "could not find user with username: #{params[:username]}",
          data: {}
      }

    end
  end

  def create
    create_params, error = create_params(
      fields: %i[role_id], required: %i[username password person_id]
    )
    return render json: { errors: create_params }, status: :bad_request if error

    if UserService.check_user(create_params[:username])
      errors = ['User already exists']
      return render json: { errors: errors }, status: :conflict
    end

    user = UserService.create_user(
      create_params[:username], create_params[:password],
      create_params[:person], create_params[:role]
    )
    if user.errors
      render json: { errors: user.errors }, status: :bad_request
    else
      render json: { user: user }, status: :created
    end
  end

  def update_user
=begin

  params = {
    username": "", password: "", first_name: "", last_name:  "", gender: "", role:   "Admin|Nurse|Clinician|Doctor",  birthdate: ""
  }
=end

    if UserService.update_user(params)

        details = UserService.compute_expiry_time
        response = {
            status: 200,
            error: false,
            message: 'account updated successfuly',
            data: {
                token: details[:token],
                expiry_time: details[:expiry_time]
            }
        }
    else
        response = {
            status: 401,
            error: true,
            message: 'failed to update user',
            data: {

        }
      }
    end

    render json: response
  end

  def login
    login_params, error = get_params required: %i[username password]
    render json: login_params, status: :bad_request && return if error

    api_key = UserService.authenticate(login_params[:username],
                                       login_params[:password])
    if api_key.nil?
      render json: { error: 'Invalid user or password' }, status: :unauthorized
    else
      render json: { authorization: api_key }
    end
  end

  def check_token_validity
    if params[:token]

      status = UserService.check_token(params[:token])
      if status == true
        response = {
          status: 200,
          error: false,
          message: 'token active',
          data: {
          }
        }
      else	
        response = {
          status: 401,
          error: true,
          message: 'invalid_',
          data: {
            
          }
        }
      end

    else
      response = {
          status: 401,
          error: true,
          message: 'token not provided',
          data: {
            
          }
        }
    end

    render json: response
  end

  def re_authenticate
    if params[:username] && params[:password]
      details = UserService.re_authenticate(params[:username],params[:password])
      if details == false
        response = {
          status: 401,
          error: true,
          message: 'wrong password or username',
          data: {
            
          }
        }
      else
        response = {
            status: 200,
            error: false,
            message: 're authenticated successfuly',
            data: {
              token: details[:token],
              expiry_time: details[:expiry_time]
            }
          }
      end

    else
      response = {
          status: 401,
          error: true,
          message: 'password or username not provided',
          data: {
            
          }
        }
    end
    render json: response
  end

  private

  def create_params
    create_params, error = required_params(
      fields: %i[role_id], required: %i[username password person_id]
    )
    return create_params, error if error

    create_params[:role] = role_id = create_params[:role_id]
    role = role_id ? Role.find(role_id) : Role.find(name: DEFAULT_ROLENAME)
    return { role_id: "Invalid role_id ##{role_id}" }, true unless role

    create_params[:person] = person = Person.find(create_params[:person_id])
    return { person_id: "Invalid person_id ##{person_id}" }, true unless person

    create_params
  end
end
