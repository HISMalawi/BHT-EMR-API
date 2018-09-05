Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      resources :users
      get '/people/_names' => 'person_names#index'
      resources :people
      resources :roles
      resources :patients

      resources :locations do
        get '/districts' => 'locations#districts'
        get '/villages' => 'locations#villages'
        get '/traditional_authorities' => 'locations#traditional_authorities'
      end

      get '/encounters/_types' => 'encounter_types#index'
      resources :encounters
      resources :observations
    end
  end

  post '/api/v1/auth/login' => 'api/v1/users#login'
  post '/api/v1/auth/verify_token' => 'api/v1/users#check_token_validity'
end
