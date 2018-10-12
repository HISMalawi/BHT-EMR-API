Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      # Helper for creating dynamic redirect urls with redirect blocks
      def paginate_url(url, params)
        page = params[:page]
        page_size = params[:page_size]

        url += "&page=#{page}" if page
        url += "&page_size=#{page_size}" if page_size
        url
      end

      # Routes down here ... Best we move everything above into own modules

      resources :appointments
      resources :dispensations, only: %i[index create]
      resources :users

      get '/people/_names' => 'person_names#index'
      resources :people do
        get('/names', to: redirect do |params, request|
          paginate_url "/api/v1/people/_names?person_id=#{params[:person_id]}",
                       request.params
        end)
      end

      resources :roles

      # Patients
      resources :patients do
        get '/labels/national_health_id' => 'patients#print_national_health_id_label'
        get '/visits' => 'patients#visits'
        get('/appointments', to: redirect do |params, request|
          paginate_url "/api/v1/appointments?patient_id=#{params[:patient_id]}",
                       request.params
        end)
        resources :patient_programs, path: :programs
      end

      resources :concepts, only: %i[index show]

      # Locations
      resources :locations

      resources :regions, only: %i[index] do
        get('/districts', to: redirect do |params, request|
          paginate_url "/api/v1/districts?region_id=#{params[:region_id]}", request.params
        end)
      end

      resources :districts, only: %i[create index] do
        get('/traditional_authorities', to: redirect do |params, request|
          redirect_url = "/api/v1/traditional_authorities?district_id=#{params[:district_id]}"
          paginate_url redirect_url, request.params
        end)
      end

      resources :traditional_authorities, only: %i[create index] do
        get('/villages', to: redirect do |params, request|
          redirect_url = "/api/v1/villages?traditional_authority_id=#{params[:traditional_authority_id]}"
          paginate_url redirect_url, request.params
        end)
      end

      resources :villages, only: %i[create index]

      get '/encounters/_types' => 'encounter_types#index'
      resources :encounters do
        get('/observations', to: redirect do |params, request|
          redirect_url = "/api/v1/observations?encounter_id=#{params[:encounter_id]}"
          paginate_url redirect_url, request.params
        end)
      end

      resources :observations

      resources :programs do
        resources :program_workflows, path: :workflows
        resources :program_regimens, path: :regimens
        resources :program_patients, path: :patients do
          get '/last_drugs_received' => 'program_patients#last_drugs_received'
        end
      end

      resources :drugs
      resources :drug_orders
      resources :orders

      resource :global_properties
      resource :user_properties

      resources :patient_states

      # Workflow engine
      get '/workflows/:program_id/:patient_id' => 'workflows#next_encounter'

      # Search
      get '/search/given_name' => 'person_names#search_given_name'
      get '/search/middle_name' => 'person_names#search_middle_name'
      get '/search/family_name' => 'person_names#search_family_name'
      get '/search/people' => 'people#search'
      get '/search/patients/by_npid' => 'patients#search_by_npid'
      get '/search/properties' => 'properties#search'

      post '/reports/encounters' => 'encounters#count'
    end
  end

  root to: 'static#index'
  get '/api/v1/_health' => 'healthcheck#index'
  post '/api/v1/auth/login' => 'api/v1/users#login'
  post '/api/v1/auth/verify_token' => 'api/v1/users#check_token_validity'
end
