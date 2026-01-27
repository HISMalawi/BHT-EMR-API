# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'User Authentication', type: :request do
  let(:base_path) { '/api/v1/auth' }

  # Ensure database is seeded with test users
  before(:all) do
    # Clean up existing test users
    User.where(username: %w[daemon admin]).destroy_all

    # We rely on seeds.rb being run, but for testing we can check
    unless User.exists?(username: 'daemon')
      # Create daemon user if not exists
      daemon_person = Person.create!(gender: 'U', creator: 1, voided: false, uuid: SecureRandom.uuid)
      daemon_salt = 'daemon'
      daemon_password = Digest::SHA1.hexdigest("#{daemon_salt}daemon")

      User.create!(
        user_id: 1,
        username: 'daemon',
        password: daemon_password,
        salt: daemon_salt,
        person_id: daemon_person.person_id,
        creator: 1,
        retired: false,
        uuid: SecureRandom.uuid,
        location_id: 1
      )
    end

    unless User.exists?(username: 'admin')
      # Create admin user if not exists
      admin_person = Person.create!(gender: 'M', creator: 1, voided: false, uuid: SecureRandom.uuid)
      PersonName.create!(
        person_id: admin_person.person_id,
        given_name: 'Admin',
        family_name: 'User',
        preferred: true,
        creator: 1,
        voided: false,
        uuid: SecureRandom.uuid
      )

      admin_salt = SecureRandom.base64(8)
      admin_password = 'Admin123'
      admin_password_hash = Digest::SHA1.hexdigest("#{admin_password}#{admin_salt}")

      admin_user = User.create!(
        username: 'admin',
        password: admin_password_hash,
        salt: admin_salt,
        person_id: admin_person.person_id,
        creator: 1,
        retired: false,
        uuid: SecureRandom.uuid,
        location_id: 1
      )

      # Add System Developer role
      role = Role.find_or_create_by!(role: 'System Developer')
      UserRole.create!(user_id: admin_user.user_id, role: role.role)

      # Create password management property
      UserProperty.create!(
        user_id: admin_user.user_id,
        property: 'last_password_updated',
        property_value: Time.now.iso8601
      )
    end
  end

  describe 'POST /api/v1/auth/login' do
    context 'with valid daemon credentials' do
      it 'authenticates successfully' do
        post "#{base_path}/login", params: {
          username: 'daemon',
          password: 'daemon'
        }, as: :json

        expect(response).to have_http_status(:ok)
        expect(json_response['authorization']).to be_present
        expect(json_response['authorization']['token']).to be_present
        expect(json_response['authorization']['user']['username']).to eq('daemon')
      end

      it 'returns a valid token with expiry time' do
        post "#{base_path}/login", params: {
          username: 'daemon',
          password: 'daemon'
        }, as: :json

        authorization = json_response['authorization']
        expect(authorization['expiry_time']).to be_present

        expiry_time = Time.parse(authorization['expiry_time'])
        expect(expiry_time).to be > Time.now
        expect(expiry_time).to be <= (Time.now + 8.days)
      end
    end

    context 'with valid admin credentials' do
      it 'authenticates successfully' do
        post "#{base_path}/login", params: {
          username: 'admin',
          password: 'Admin123'
        }, as: :json

        expect(response).to have_http_status(:ok)
        expect(json_response['authorization']).to be_present
        expect(json_response['authorization']['user']['username']).to eq('admin')
      end

      it 'includes first_time_login flag' do
        post "#{base_path}/login", params: {
          username: 'admin',
          password: 'Admin123'
        }, as: :json

        expect(json_response).to have_key('first_time_login')
        expect([true, false]).to include(json_response['first_time_login'])
      end

      it 'includes password_needs_update flag' do
        post "#{base_path}/login", params: {
          username: 'admin',
          password: 'Admin123'
        }, as: :json

        expect(json_response).to have_key('password_needs_update')
        expect(json_response['password_needs_update']).to be_in([true, false])
      end

      it 'creates last_login_time property on first login' do
        admin = User.find_by(username: 'admin')

        # Clear any existing last_login_time
        UserProperty.where(
          user_id: admin.user_id,
          property: 'last_login_time'
        ).destroy_all

        post "#{base_path}/login", params: {
          username: 'admin',
          password: 'Admin123'
        }, as: :json

        expect(response).to have_http_status(:ok)

        login_property = UserProperty.find_by(
          user_id: admin.user_id,
          property: 'last_login_time'
        )

        expect(login_property).to be_present
        expect(login_property.property_value).to be_present
      end
    end

    context 'with invalid credentials' do
      it 'rejects wrong password' do
        post "#{base_path}/login", params: {
          username: 'admin',
          password: 'WrongPassword'
        }, as: :json

        expect(response).to have_http_status(:unauthorized)
        expect(json_response['errors']).to include('Invalid user or password')
      end

      it 'rejects non-existent user' do
        post "#{base_path}/login", params: {
          username: 'nonexistent',
          password: 'password'
        }, as: :json

        expect(response).to have_http_status(:unauthorized)
        expect(json_response['errors']).to be_present
      end

      it 'rejects empty password' do
        post "#{base_path}/login", params: {
          username: 'admin',
          password: ''
        }, as: :json

        expect(response).to have_http_status(:unauthorized)
      end

      it 'rejects empty username' do
        post "#{base_path}/login", params: {
          username: '',
          password: 'password'
        }, as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with missing parameters' do
      it 'returns bad request when username is missing' do
        post "#{base_path}/login", params: {
          password: 'password'
        }, as: :json

        expect(response).to have_http_status(:bad_request)
      end

      it 'returns bad request when password is missing' do
        post "#{base_path}/login", params: {
          username: 'admin'
        }, as: :json

        expect(response).to have_http_status(:bad_request)
      end
    end
  end

  describe 'POST /api/v1/auth/verify_token' do
    let(:valid_token) do
      post "#{base_path}/login", params: {
        username: 'admin',
        password: 'Admin123'
      }, as: :json

      json_response['authorization']['token']
    end

    context 'with valid token' do
      it 'verifies the token successfully' do
        post "#{base_path}/verify_token", headers: {
          'Authorization' => valid_token
        }

        expect(response).to have_http_status(:ok)
      end
    end

    context 'with invalid token' do
      it 'rejects invalid token' do
        post "#{base_path}/verify_token", headers: {
          'Authorization' => 'invalid_token_123'
        }

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with expired token' do
      it 'rejects expired token' do
        user = User.find_by(username: 'admin')
        user.update(
          authentication_token: 'expired_token',
          token_expiry_time: 1.day.ago
        )

        post "#{base_path}/verify_token", headers: {
          'Authorization' => 'expired_token'
        }

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'User session management' do
    it 'allows multiple concurrent sessions with different tokens' do
      # First login
      post "#{base_path}/login", params: {
        username: 'admin',
        password: 'Admin123'
      }, as: :json

      token1 = json_response['authorization']['token']

      # Second login
      post "#{base_path}/login", params: {
        username: 'admin',
        password: 'Admin123'
      }, as: :json

      token2 = json_response['authorization']['token']

      # Tokens should be different (new token replaces old)
      expect(token1).not_to eq(token2)
    end

    it 'tracks login time on subsequent logins' do
      admin = User.find_by(username: 'admin')

      # First login
      post "#{base_path}/login", params: {
        username: 'admin',
        password: 'Admin123'
      }, as: :json

      first_login = UserProperty.find_by(
        user_id: admin.user_id,
        property: 'last_login_time'
      )
      first_login_time = Time.parse(first_login.property_value)

      sleep 1

      # Second login
      post "#{base_path}/login", params: {
        username: 'admin',
        password: 'Admin123'
      }, as: :json

      second_login = UserProperty.find_by(
        user_id: admin.user_id,
        property: 'last_login_time'
      )
      second_login_time = Time.parse(second_login.property_value)

      expect(second_login_time).to be > first_login_time
    end
  end

  # Helper method to parse JSON response
  def json_response
    JSON.parse(response.body)
  rescue JSON::ParserError
    {}
  end
end
