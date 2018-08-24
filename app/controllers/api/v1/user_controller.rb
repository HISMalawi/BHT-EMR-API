require 'user_service.rb'

class Api::V1::UserController < ApplicationController

  #before_action :check_if_token_valid
  def create_user
=begin

  params = {
    app_name: "",
    password: "",
    username": "",
    location_id: "",
    gender: "",
    birthdate: ""
  }
=end

		if params[:location_id] &&
        params[:app_name] &&
        params[:password] &&
        params[:username] &&
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
