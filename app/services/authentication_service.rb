# frozen_string_literal: true

##
# Authenticates users locally and with external services via SSS
#
# @see https://github.com/EGPAFMalawiHIS/SSS
module AuthenticationService
  class << self
    ##
    # Logs in a user using the user's username and password
    #
    # Returns:  A User object
    # Raises: LoginError if login failed for some reason
    def login(username, password)
      login_provider = find_login_provider(username)
      user = login_provider.login(username, password)
      raise LoginFailed, 'Invalid username or password' unless user

      token, expires = generate_jwt(user)
      { token: token, expires: expires, user: user }
    end

    private

    def find_login_provider(username)
      return SssProvider if username.match(/^\w+[A-Z0-9\-_.]+@.+$/i)

      LocalAccountsProvider
    end
  end

  class LoginFailed < InvalidParameterError; end

  ##
  # Authenticates users using local accounts.
  module LocalAccountsProvider
    def self.login(username, password)
      user = User.find_by_username(username)
      return nil unless user

      return user if BCrypt::Password.new(user.password_digest) == password

      # Deprecated: Attempt a legacy login and migrate user to new system
      return nil unless legacy_local_login(username, password)

      user.password_digest = BCrypt::Password.create(password)
      user.save
      user
    end

    ##
    # Login using old ART mechanism
    def self.legacy_login(user, password)
      user.active?\
        && (UserService.bart_authenticate(user, password)\
              || UserService.new_arch_authenticate(user, password))
    end
  end

  ##
  # Authenticates users using SSS
  module SssProvider
    def self.login(_username, _password)
      raise 'Not implemented'
    end
  end
end
