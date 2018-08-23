Rails.application.routes.draw do

  namespace :api do

    namespace :v1 do

      post '/create_user/:token'						         		 =>	'user#create_user'
  		get	 '/authenticate/:username/:password' 				 		 =>	'user#authenticate_user'
  		get	 '/re_authenticate/:username/:password'						 =>	'user#re_authenticate'
  		get	 '/check_token_validity/:token' 							 =>	'user#check_token_validity'

    end

  end
end
