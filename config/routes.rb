Rails.application.routes.draw do

  namespace :api do

    namespace :v1 do

      #User APIs
      get '/user/index/:token'						       =>	'user#index'
      get '/user/find/:username/:token'						       =>	'user#get_user'
      post '/user/create/:token'						       =>	'user#create_user'
      post '/user/update/:username/:token'						       =>	'user#update_user'
  		get	 '/user/authenticate/:username/:password' 		 =>	'user#authenticate_user'
  		get	 '/user/check_token_validity/:token' 				 =>	'user#check_token_validity'

      #Location APIs
      get '/regions/index/:token'                           => 'location#regions'
      get '/districts/index/:region_id/:token'              => 'location#districts'
      get '/tas/index/:district_id/:token'                  => 'location#tas'
      get '/villages/index/:ta_id/:token'                   => 'location#villages'

    end

  end
end
