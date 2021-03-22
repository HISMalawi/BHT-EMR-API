module Helpers
  module Authentication
    def login_as(username, password)
      login_data = JSON.dump({ username: username, password: password })
      headers = { 'Content-type' => 'application/json' }
      post api_v1_auth_login_path, params: login_data, headers: headers
      Rails.logger.debug response.body
    end
  end
end
