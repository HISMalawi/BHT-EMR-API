# frozen_string_literal: true

Rails.application.routes.draw do
  mount Lab::Engine => '/'
  # mount Radiology::Engine => '/'
  mount EmrOhspInterface::Engine => '/'
  mount Rswag::Ui::Engine => '/api-docs'
  mount Rswag::Api::Engine => '/api-docs'

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
      resources :internal_sections, only: %i[index show create update destroy]
      resources :data_cleaning_supervisions, only: %i[index show create update destroy]
      resources :appointments
      resources :dispensations, only: %i[index create destroy]
      resources :users do
        post '/activate', to: 'users#activate'
        post '/deactivate', to: 'users#deactivate'
      end

      resources :hts_reports, only: %i[index]
      get '/hts_stats' => 'hts_reports#daily_stats'
      get '/valid_provider_id', to: 'people#valid_provider_id'
      get '/next_hts_linkage_ids_batch', to: 'people#next_hts_linkage_ids_batch'

      # notifications for nlims any features in the future
      resources :notifications, only: %i[index update] do
        collection do
          put '/clear/:id', to: 'notifications#clear'
        end
      end

      # Not placed under users urls to allow crud on current user's roles
      resources :user_roles, only: %i[index create destroy]

      get '/people/_names' => 'person_names#index'
      resources :people do
        resources :person_relationships, path: :relationships

        get '/guardians', to: 'person_relationships#guardians'

        get('/names', to: redirect do |params, request|
          paginate_url "/api/v1/people/_names?person_id=#{params[:person_id]}",
                       request.params
        end)
      end

      resources :roles

      # Patients
      resources :patients do
        get '/labels/national_health_id' => 'patients#print_national_health_id_label'
        get '/labels/filing_number' => 'patients#print_filing_number'
        get 'labels/print_tb_number', to: 'patients#print_tb_number'
        get 'labels/print_hts_linkage_code/:code', to: 'patients#print_hts_linkage_code'
        get 'labels/print_tb_lab_order_summary', to: 'patients#print_tb_lab_order_summary'
        get '/visits' => 'patients#visits'
        get '/visit' => 'patients#visit'
        get('/appointments', to: redirect do |params, request|
          paginate_url "/api/v1/appointments?patient_id=#{params[:patient_id]}",
                       request.params
        end)
        get '/tpt_status' => 'patients#tpt_status'
        get '/drugs_received', to: 'patients#drugs_received'
        get '/last_drugs_received', to: 'patients#last_drugs_received'
        get '/drugs_orders_by_program', to: 'patients#drugs_orders_by_program'
        get '/recent_lab_orders', to: 'patients#recent_lab_orders'
        get '/current_bp_drugs', to: 'patients#current_bp_drugs'
        get '/last_bp_drugs_dispensation', to: 'patients#last_bp_drugs'
        get '/next_appointment_date', to: 'patient_appointments#next_appointment_date'
        get '/median_weight_height', to: 'patients#find_median_weight_and_height'
        get '/bp_trail', to: 'patients#bp_readings_trail'
        get '/eligible_for_htn_screening', to: 'patients#eligible_for_htn_screening'
        post '/filing_number', to: 'patients#assign_filing_number'
        get '/past_filing_numbers' => 'patients#filing_number_history'
        get 'assign_tb_number', to: 'patients#assign_tb_number'
        post '/npid', to: 'patients#assign_npid'
        post '/remaining_bp_drugs', to: 'patients#remaining_bp_drugs'
        post '/update_or_create_htn_state', to: 'patients#update_or_create_htn_state'
        resources :patient_programs, path: :programs, controller: 'patients/programs'
      end

      resources :patient_identifiers

      resources :person_attributes

      resources :concepts, only: %i[index show]

      # OPD
      get 'OPD_drugslist' => 'drugs#OPD_drugslist'

      # Locations
      resources :locations do
        get('/label', to: redirect do |params, _request|
          "/api/v1/labels/location?location_id=#{params[:location_id]}"
        end)

        collection do
          get :current_facility
        end
      end

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

      resources :patient_programs, only: %i[create index show destroy]

      resources :programs do
        resources :program_workflows, path: :workflows
        resources :program_regimens, path: :regimens
        get 'regimen_extras' => 'program_regimens#regimen_extras'

        get 'booked_appointments' => 'program_appointments#booked_appointments'
        get 'scheduled_appointments' => 'program_appointments#scheduled_appointments'
        get 'next_available_arv_number' => 'program_patients#find_next_available_arv_number'
        get 'lookup_arv_number/:arv_number' => 'program_patients#lookup_arv_number'
        get 'regimen_starter_packs' => 'program_regimens#find_starter_pack'
        get 'custom_regimen_ingredients' => 'program_regimens#custom_regimen_ingredients'
        get 'custom_tb_ingredients' => 'program_regimens#custom_tb_ingredients'
        get 'defaulter_list' => 'program_patients#defaulter_list'
        get '/barcodes/:barcode_name', to: 'program_barcodes#print_barcode'
        post 'void_arv_number/:arv_number' => 'program_patients#void_arv_number'

        resources :program_patients, path: 'patients' do
          get '/next_appointment_date' => 'patient_appointments#next_appointment_date'
          get '/last_drugs_received' => 'program_patients#last_drugs_received'
          get '/dosages' => 'program_patients#find_dosages'
          get '/status' => 'program_patients#status'
          get '/earliest_start_date' => 'program_patients#find_earliest_start_date'
          get '/labels/visits', to: 'program_patients#print_visit_label'
          get '/labels/history', to: 'program_patients#print_history_label'
          get '/labels/lab_results', to: 'program_patients#print_lab_results_label'
          get '/labels/transfer_out', to: 'program_patients#print_transfer_out_label'
          get '/labels/patient_history', to: 'program_patients#print_patient_history_label'
          get '/mastercard_data', to: 'program_patients#mastercard_data'
          get '/medication_side_effects', to: 'program_patients#medication_side_effects'
          get '/is_due_lab_order', to: 'program_patients#is_due_lab_order'
          # ANC
          get '/vl_info', to: 'lab_remainders#index'
          # ANC
          get '/surgical_history', to: 'program_patients#surgical_history'
          get '/anc_visit', to: 'program_patients#anc_visit'
          get '/art_hiv_status', to: 'program_patients#art_hiv_status'
          get '/subsequent_visit', to: 'program_patients#subsequent_visit'
          get '/saved_encounters', to: 'program_patients#saved_encounters'
          resources :patient_states, path: :states
          resources :visit, only: %i[index], module: 'programs/patients'
          resources :drug_doses, only: %i[index], module: 'programs/patients'
        end
        resources :lab_test_types, path: 'lab_tests/types'
        get '/lab_tests/panels' => 'lab_test_types#panels' # TODO: Move this into own controller
        resources :lab_test_orders, path: 'lab_tests/orders'
        post '/lab_tests/orders/external' => 'lab_test_orders#create_external_order'
        post '/lab_tests/orders/lims-old' => 'lab_test_orders#create_legacy_order' # Temporary path for creating legacy LIMS orders
        get '/lab_tests/labels/order', to: 'lab_test_labels#print_order_label'
        resources :lab_test_results, path: 'lab_tests/results'
        post '/lab_tests/order_and_results' => 'lab_test_results#create_order_and_results'
        get '/lab_tests/locations' => 'lab_test_orders#locations'
        get '/lab_tests/labs' => 'lab_test_orders#labs'
        get '/lab_tests/orders_without_results' => 'lab_test_orders#orders_without_results'
        get '/lab_tests/measures' => 'lab_test_types#measures'
        get '/labs/:resource', to: 'lab#dispatch_request'
        resources :program_reports, path: 'reports'
      end

      namespace :pharmacy do
        resource :audit_trail, only: %i[show]
        resource :drug_movement, only: %i[show]
        resources :batches
        resources :stock_verifications
        resources :items do
          post '/reallocate', to: 'items#reallocate'
          post '/dispose', to: 'items#dispose'
        end
        get 'earliest_expiring_item', to: 'items#earliest_expiring'
        get 'drug_consumption', to: 'drugs#drug_consumption'
        get 'stock_report', to: 'audit_trails#stock_report'
        get '/audit_trail/grouped', to: 'audit_trails#show_grouped_audit_trail'
      end

      namespace :types do
        resources :relationships
        resources :lab_tests
        resources :patient_identifiers
      end

      resources :drugs do
        get '/barcode', to: 'drugs#print_barcode'
      end
      get '/arv_drugs' => 'drugs#arv_drugs'
      get '/tb_drugs' => 'drugs#tb_drugs'
      get '/bp_drugs' => 'drugs#bp_drugs'

      resources :drug_orders
      resources :orders do
        get '/radiology', to: 'orders#print_radiology_order', on: :collection
        post '/radiology', to: 'orders#radiology_order', on: :collection
      end

      get '/drug_sets', to: 'drugs#drug_sets' # ANC get drug sets
      post '/drug_sets', to: 'drugs#create_drug_sets' # ANC drug sets creation
      delete '/drug_sets/:id', to: 'drugs#void_drug_sets'

      resource :global_properties
      resource :user_properties
      get '/validate_properties' => 'user_properties#unique_property'

      resource :session_stats, path: 'stats/session'

      resources :diagnosis

      # Workflow engine
      get '/workflows/:program_id/:patient_id' => 'workflows#next_encounter'

      get '/current_time', to: 'time#current_time'

      get '/dde/patients/find_by_npid', to: 'dde#find_patients_by_npid'
      get '/dde/patients/find_by_name_and_gender', to: 'dde#find_patients_by_name_and_gender'
      get '/dde/patients/import_by_doc_id', to: 'dde#import_patients_by_doc_id'
      get '/dde/patients/import_by_name_and_gender', to: 'dde#import_patients_by_name_and_gender'
      get '/dde/patients/import_by_npid', to: 'dde#import_patients_by_npid'
      get '/dde/patients/match_by_demographics', to: 'dde#match_patients_by_demographics'
      get '/dde/patients/diff', to: 'dde#patient_diff'
      get '/dde/patients/refresh', to: 'dde#refresh_patient'
      post '/dde/patients/reassign_npid', to: 'dde#reassign_patient_npid'
      post '/dde/patients/merge', to: 'dde#merge_patients'
      get '/dde/patients/remaining_npids', to: 'dde#remaining_npids'
      get '/rollback/merge_history', to: 'rollback#merge_history'
      post '/rollback/rollback_patient', to: 'rollback#rollback_patient'

      get '/labels/location', to: 'locations#print_label'

      # Search
      get '/search/given_name' => 'person_names#search_given_name'
      get '/search/middle_name' => 'person_names#search_middle_name'
      get '/search/family_name' => 'person_names#search_family_name'
      get '/search/people' => 'people#search'
      get '/search/patients/by_npid' => 'patients#search_by_npid'
      get '/search/patients/by_identifier' => 'patients#search_by_identifier'
      get '/search/patients' => 'patients#search_by_name_and_gender'
      get '/search/properties' => 'properties#search'
      get '/search/landmarks' => 'landmarks#search'
      get '/search/identifiers/duplicates' => 'patient_identifiers#duplicates'
      get '/search/identifiers/multiples' => 'patient_identifiers#multiples'

      get '/dde/patients/find_by_npid', to: 'dde#find_patients_by_npid'
      get '/dde/patients/find_by_name_and_gender', to: 'dde#find_patients_by_name_and_gender'
      get '/dde/patients/import_by_doc_id', to: 'dde#import_patients_by_doc_id'
      get '/dde/patients/import_by_name_and_gender', to: 'dde#import_patients_by_name_and_gender'
      get '/dde/patients/import_by_npid', to: 'dde#import_patients_by_npid'
      get '/dde/patients/match_by_demographics', to: 'dde#match_patients_by_demographics'
      post '/dde/patients/reassign_npid', to: 'dde#reassign_patient_npid'
      post '/dde/patients/merge', to: 'dde#merge_patients'

      get '/sequences/next_accession_number', to: 'sequences#next_accession_number'

      post '/reports/encounters' => 'encounters#count'

      # drugs_cms routes
      get '/drug_cms/search', to: 'drug_cms#search'
      resources :drug_cms, only: %i[index]
    end
  end

  root to: 'static#index'
  get '/api/v1/archiving_candidates' => 'api/v1/patients#find_archiving_candidates'
  get '/api/v1/_health' => 'healthcheck#index'
  post '/api/v1/auth/login' => 'api/v1/users#login'
  post '/api/v1/auth/verify_token' => 'api/v1/users#check_token_validity'
  get '/api/v1/fast_track_assessment' => 'api/v1/fast_track#assessment'
  post '/api/v1/cancel_fast_track' => 'api/v1/fast_track#cancel'
  get '/api/v1/on_fast_track' => 'api/v1/fast_track#on_fast_track'
  get '/api/v1/patient_weight_for_height_values' => 'api/v1/weight_for_height#index'
  get '/api/v1/presenting_complaints' => 'api/v1/presenting_complaints#show'
  get '/api/v1/concept_set' => 'api/v1/concept_sets#show'
  get '/api/v1/radiology_set' => 'api/v1/concept_sets#radiology_set'
  get '/api/v1/radiology/examinations' => 'api/v1/radiology#examinations'
  get '/api/v1/cervical_cancer_screening' => 'api/v1/cervical_cancer_screening#show'

  get '/api/v1/dashboard_stats' => 'api/v1/reports#index'
  get '/api/v1/dashboard_stats_for_syndromic_statistics' => 'api/v1/reports#syndromic_statistics'
  post '/api/v1/vl_maternal_status' => 'api/v1/reports#vl_maternal_status'
  post '/api/v1/patient_art_vl_dates' => 'api/v1/reports#patient_art_vl_dates'

  # SQA controller
  post '/api/v1/duplicate_identifier' => 'api/v1/cleaning#duplicate_identifier'
  post '/api/v1/erroneous_identifier' => 'api/v1/cleaning#erroneous_identifier'
  get '/api/v1/dead_encounters' => 'api/v1/cleaning#index'
  get '/api/v1/date_enrolled' => 'api/v1/cleaning#dateEnrolled'
  get '/api/v1/start_date' => 'api/v1/cleaning#startDate'
  get '/api/v1/male' => 'api/v1/cleaning#male'
  get '/api/v1/incomplete_visits' => 'api/v1/cleaning#incompleteVisits'
  get '/api/v1/art_data_cleaning_tools' => 'api/v1/cleaning#art_tools'
  get '/api/v1/anc_data_cleaning_tools' => 'api/v1/cleaning#anc_tools'
  get '/api/v1/its_data_cleaning_tools' => 'api/v1/cleaning#its_tools'

  # OPD reports
  get '/api/v1/registration' => 'api/v1/reports#registration'
  get '/api/v1/diagnosis_by_address' => 'api/v1/reports#diagnosis_by_address'
  get '/api/v1/with_nids' => 'api/v1/reports#with_nids'
  get '/api/v1/dispensation' => 'api/v1/reports#dispensation'

  get '/api/v1/cohort_report_raw_data' => 'api/v1/reports#cohort_report_raw_data'
  get '/api/v1/cohort_disaggregated' => 'api/v1/reports#cohort_disaggregated'
  get '/api/v1/anc_cohort_disaggregated' => 'api/v1/reports#anc_cohort_disaggregated'
  get '/api/v1/cohort_survival_analysis' => 'api/v1/reports#cohort_survival_analysis'
  get '/api/v1/defaulter_list' => 'api/v1/reports#defaulter_list'
  get '/api/v1/missed_appointments' => 'api/v1/reports#missed_appointments'
  post '/api/v1/addresses' => 'api/v1/person_addresses#create'
  get '/api/v1/archive_active_filing_number' => 'api/v1/patient_identifiers#archive_active_filing_number'
  delete '/api/v1/void_multiple_identifiers' => 'api/v1/patient_identifiers#void_multiple_identifiers'
  get '/api/v1/ipt_coverage' => 'api/v1/reports#ipt_coverage'
  get '/api/v1/cohort_report_drill_down' => 'api/v1/reports#cohort_report_drill_down'
  post '/api/v1/swap_active_number' => 'api/v1/patient_identifiers#swap_active_number'
  get '/api/v1/regimen_switch' => 'api/v1/reports#regimen_switch'
  get '/api/v1/last_drugs_pill_count' => 'api/v1/patients#last_drugs_pill_count'
  get '/api/v1/anc/visits', to: 'api/v1/anc#visits'

  get '/api/v1/regimen_report' => 'api/v1/reports#regimen_report'
  get '/api/v1/anc/deliveries', to: 'api/v1/anc#deliveries'
  get '/api/v1/anc/essentials', to: 'api/v1/anc#essentials'
  get '/api/v1/screened_for_tb', to: 'api/v1/reports#screened_for_tb'
  get '/api/v1/clients_given_ipt', to: 'api/v1/reports#clients_given_ipt'
  get '/api/v1/temp_earliest_start_table_exisit', to: 'healthcheck#temp_earliest_start_table_exisit'
  get '/api/v1/version', to: 'healthcheck#version'
  get '/api/v1/database_backup_files', to: 'healthcheck#database_backup_files'
  get '/api/v1/user_system_usage', to: 'healthcheck#user_system_usage'
  get '/api/v1/arv_refill_periods', to: 'api/v1/reports#arv_refill_periods'
  get '/api/v1/tx_ml', to: 'api/v1/reports#tx_ml'
  get '/api/v1/tx_rtt', to: 'api/v1/reports#tx_rtt'
  get '/api/v1/disaggregated_regimen_distribution', to: 'api/v1/reports#disaggregated_regimen_distribution'
  post '/api/v1/tx_mmd_client_level_data', to: 'api/v1/reports#tx_mmd_client_level_data'
  get '/api/v1/clients', to: 'api/v1/people#list'
  get '/api/v1/tb_prev', to: 'api/v1/reports#tb_prev'
  get '/api/v1/moh_tpt', to: 'api/v1/reports#moh_tpt'
  get '/api/v1/tpt_prescription_count' => 'api/v1/patients#tpt_prescription_count'
  get '/api/v1/patient_visit_types', to: 'api/v1/reports#patient_visit_types'
  get '/api/v1/patient_visit_list', to: 'api/v1/reports#patient_visit_list'
  get '/api/v1/patient_outcome_list', to: 'api/v1/reports#patient_outcome_list'
  get '/api/v1/clients_due_vl', to: 'api/v1/reports#clients_due_vl'
  get '/api/v1/last_cxca_screening_details' => 'api/v1/patients#last_cxca_screening_details'
  get '/api/v1/vl_results', to: 'api/v1/reports#vl_results'
  get '/api/v1/samples_drawn', to: 'api/v1/reports#samples_drawn'
  get '/api/v1/lab_test_results', to: 'api/v1/reports#lab_test_results'
  get '/api/v1/orders_made', to: 'api/v1/reports#orders_made'
  get '/api/v1/:program_id/external_consultation_clients', to: 'api/v1/reports#external_consultation_clients'

  get '/api/v1/screened_for_cxca', to: 'api/v1/reports#cxca_reports'
  get '/api/v1/pepfar_cxca', to: 'api/v1/reports#cxca_reports'
  get '/api/v1/dispatch_order/:order_id', to: 'api/v1/dispatch_orders#show'
  post '/api/v1/dispatch_order', to: 'api/v1/dispatch_orders#create'
  get '/api/v1/latest_regimen_dispensed', to: 'api/v1/reports#latest_regimen_dispensed'
  get '/api/v1/sc_arvdisp', to: 'api/v1/reports#sc_arvdisp'

  get 'api/v1/radiology_reports', to: 'api/v1/reports#radiology_reports'

  post '/api/v1/pharmacy/items/batch_update', to: 'api/v1/pharmacy/items#batch_update'

  get '/api/v1/next_appointment', to: 'api/v1/appointments#next_appointment'

  post 'api/v1/sync_to_ait', to: 'api/v1/patients#sync_to_ait'
end
