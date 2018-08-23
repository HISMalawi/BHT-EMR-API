Rails.application.routes.draw do

  namespace :api do

    namespace :v1 do

      #User APIs
      post '/create_user/:token'						       =>	'user#create_user'
  		get	 '/authenticate/:username/:password' 		 =>	'user#authenticate_user'
  		get	 '/re_authenticate/:username/:password'	 =>	'user#re_authenticate'
  		get	 '/check_token_validity/:token' 				 =>	'user#check_token_validity'

      #Location APIs
      get '/get_regions/:token'                           => 'location#regions'
      get '/get_facilities/:district_id/:token'           => 'location#facilities'
      get '/get_districts/:region_id/:token'              => 'location#districts'
      get '/get_tas/:district_id/:token'                  => 'location#tas'
      get '/get_villages/:ta_id/:token'                   => 'location#villages'

    end

  end
end
