Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      resources :users
      resources :locations
      resources :people
      resources :roles
    end
  end

  post '/api/v1/auth/login' => 'api/v1/users#login'
  post '/api/v1/auth/verify_token' => 'api/v1/users#check_token_validity'
end
