EmrOhspInterface::Engine.routes.draw do
    resources :emr_lims_interface, path: 'api/v1/emr_lims_interface'
    get '/get_lims_user', to: 'emr_lims_interface#get_user_info'
    get '/get_weeks', to: 'emr_ohsp_interface#weeks_generator'
    get '/get_months', to: 'emr_ohsp_interface#months_generator'
    get '/generate_weekly_idsr_report', to: 'emr_ohsp_interface#generate_weekly_idsr_report'
    get '/generate_monthly_idsr_report', to: 'emr_ohsp_interface#generate_monthly_idsr_report'
    get '/generate_hmis_15_report', to: 'emr_ohsp_interface#generate_hmis_15_report'
    get '/generate_hmis_17_report', to: 'emr_ohsp_interface#generate_hmis_17_report'

    # for the new crossplatform OPD system
    get 'api/v1/get_lims_user', to: 'emr_lims_interface#get_user_info'
    get 'api/v1/get_weeks', to: 'emr_ohsp_interface#weeks_generator'
    get 'api/v1/get_months', to: 'emr_ohsp_interface#months_generator'
    get 'api/v1/generate_weekly_idsr_report', to: 'emr_ohsp_interface#generate_weekly_idsr_report'
    get 'api/v1/generate_monthly_idsr_report', to: 'emr_ohsp_interface#generate_monthly_idsr_report'
    get 'api/v1/generate_hmis_15_report', to: 'emr_ohsp_interface#generate_hmis_15_report'
    get 'api/v1/generate_hmis_17_report', to: 'emr_ohsp_interface#generate_hmis_17_report'
end
