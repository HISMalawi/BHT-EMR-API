Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      resource :users
      resource :locations

      namespace :auth do
        post '/login' => 'user#authenticate_user'
        post '/verify_token' => 'user#check_token_validity'
      end
    end
  end
end
