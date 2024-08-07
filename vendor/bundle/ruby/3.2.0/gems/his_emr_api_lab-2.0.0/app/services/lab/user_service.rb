# frozen_string_literal: true

module Lab
  # Service for managing LIMS users
  module UserService
    class << self
      include BCrypt

      def create_lims_user(username:, password:)
        validate username: username
        ActiveRecord::Base.transaction do
          person = create_lims_person
          create_user username: username, password: password, person: person
        end
      end

      def authenticate_user(username:, password:, user_agent:, request_ip:)
        user = User.find_by_username username
        encrypted_pass = Password.new(user.password)
        if encrypted_pass == password
          generate_token(user, user_agent, request_ip)
        else
          # throw authentication error
          nil
        end
      end

      private

      ##
      # Validate that the username doesn't already exists
      def validate(username:)
        raise UnprocessableEntityError, 'Username already exists' if User.find_by_username username
      end

      def create_lims_person
        god_user = User.first
        person = Person.create!(creator: god_user.id)
        PersonName.create!(given_name: 'Lims', family_name: 'User', creator: god_user.id, person: person)
        person
      end

      def create_user(username:, password:, person:)
        salt = SecureRandom.base64
        user = User.create!(
          username: username,
          password: Password.create(password),
          salt: salt,
          person: person,
          creator: User.first.id
        )
      end

      def generate_token(user, user_agent, request_ip)
        browser = Browser.new(user_agent)
        key_supplement = request_ip + browser.name + browser.version
        token = Lab::JsonWebTokenService.encode({ user_id: user.id }, key_supplement)
        { auth_token: token }
      end
    end
  end
end
