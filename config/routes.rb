Rails.application.routes.draw do

  namespace :api do

    namespace :v1 do

      #User APIs
      get '/user/:token'						       =>	'user#index'
      get '/user/:id/:token'						       =>	'user#get_user'
      post '/user/create/:token'						       =>	'user#create_user'
      post '/user/update/:token'						       =>	'user#update_user'
  		get	 '/user/authenticate/:username/:password' 		 =>	'user#authenticate_user'
  		get	 '/user/check_token_validity/:token' 				 =>	'user#check_token_validity'

      #Location APIs
      get '/regions/:token'                           => 'location#regions'
      get '/districts/:region_id/:token'              => 'location#districts'
      get '/tas/:district_id/:token'                  => 'location#tas'
      get '/villages/:ta_id/:token'                   => 'location#villages'

    end

  end
end
