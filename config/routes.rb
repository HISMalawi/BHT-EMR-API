Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      resources :users

      get '/people/_names' => 'person_names#index'
      resources :people do
        get '/names', to: redirect('/api/v1/people/_names?person_id=%{person_id}')
      end

      resources :roles
      resources :patients
      resources :concepts, only: %i[index show]

      get '/locations/_districts' => 'locations#districts'
      get '/locations/_villages' => 'locations#villages'
      get '/locations/_traditional_authorities' => 'locations#traditional_authorities'
      resources :locations

      get '/encounters/_types' => 'encounter_types#index'
      resources :encounters do
        get '/observations', to: redirect('/api/v1/observations?encounter_id=%{encounter_id}')
      end

      resources :observations

      get '/search/given_name' => 'person_names#search_given_name'
      get '/search/middle_name' => 'person_names#search_middle_name'
      get '/search/family_name' => 'person_names#search_family_name'
    end
  end

  post '/api/v1/auth/login' => 'api/v1/users#login'
  post '/api/v1/auth/verify_token' => 'api/v1/users#check_token_validity'
end
