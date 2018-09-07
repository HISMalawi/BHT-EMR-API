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

      # Locations
      resources :locations

      resources :regions, only: %i[index] do
        get '/districts', to: redirect('/api/v1/districts?region_id=%{region_id}')
      end

      resources :districts, only: %i[index] do
        get '/traditional_authorities', to: redirect('/api/v1/traditional_authorities?district_id=%{district_id}')
      end

      resources :traditional_authorities, only: %i[index] do
        get '/villages', to: redirect('/api/v1/villages?traditional_authority_id=%{traditional_authority_id}')
      end

      resources :villages, only: %i[index]

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
