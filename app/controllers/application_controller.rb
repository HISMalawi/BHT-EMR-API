class ApplicationController < ActionController::API

  def check_if_token_valid
    if params[:token]

      status = UserService.check_token(params[:token])
      if status == true
       return true
      else
        response = {
            status: 401,
            error: true,
            message: 'invalid_token',
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

    render json: response and return
  end
end
