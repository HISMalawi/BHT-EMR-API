require 'user_service.rb'

class Api::V1::UserController < ApplicationController

  before_action :check_if_token_valid
  skip_before_action :check_if_token_valid, only: [:authenticate_user]

  def index
    results = []

    User.all.each{|user|
      person = Person.find(user.person_id)
      name   = PersonName.find(user.person_id)

      results << {
          username:  user.username,
          first_name: name.first_name,
          last_lame: name.last_name,
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
    person = Person.find(user.person_id).first
    name   = PersonName.where(person_id: user.person_id).last

    if user.blank? || person.blank? || name.blank?
      render json: {
          status: 200,
          error: false,
          message: 'user found',
          data: {
              username:  user.username,
              first_name: name.first_name,
              last_lame: name.last_name,
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

  def create_user
=begin

  params = {
    username": "", password: "", first_name: "", last_name:  "", gender: "", role:   "Admin|Nurse|Clinician|Doctor",  birthdate: ""
  }
=end

		if  params[:password] &&
        params[:username] &&
        params[:first_name] &&
        params[:last_name] &&
        params[:role]  &&
        params[:token]

			  status = UserService.check_user(params[:username])

        if status == false

				details = UserService.create_user(params)
				response = {
						status: 200,
						error: false,
						message: 'account created successfuly',
						data: {
							token: details[:token],
							expiry_time: details[:expiry_time]
						}
					}
			else
				response = {
					status: 401,
					error: true,
					message: 'username already taken',
					data: {

					}
				}
			end

		else
			response = {
					status: 401,
					error: true,
					message: 'missing parameter, please check',
					data: {

					}
			}
		end

		render json: response
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

  def authenticate_user

		if params[:username] && params[:password]

			status = UserService.authenticate(params[:username],params[:password])

			if (status == true)

				details = UserService.compute_expiry_time
        UserService.set_token(params[:username], details[:token], details[:expiry_time])

				response = {
					status: 200,
					error: false,
					message: 'authenticated',
					data: {
						token: details[:token],
						expiry_time: details[:expiry_time]
					}
				}
			else
				response = {
					status: 401,
					error: true,
					message: 'not authenticated',
					data: {
						token: ""
					}
				}
			end
		else
			response = {
					status: 401,
					error: true,
					message: 'username or password not provided',
					data: {
						token: ""
					}
				}
		end

		render json: response
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

end
