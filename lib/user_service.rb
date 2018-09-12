# frozen_string_literal: true

require 'logger'
require 'securerandom'

require_relative 'person_service'

module UserService
  AUTHENTICATION_TOKEN_VALIDITY_PERIOD = 24.hours
  LOGGER = Logger.new STDOUT

  class UserCreateError < StandardError; end

  def self.create_user(username:, password:, given_name:, family_name:, role:)
    person = PersonService.create_person(
      birthdate: nil, birthdate_estimated: false, gender: nil
    )
    raise UserCreateError, "Person: #{person.errors}" unless person.errors.empty?

    person_name = PersonService.create_person_name(
      person, given_name: given_name, family_name: family_name
    )
    raise UserCreateError, "Person name: #{person_name.errors}" unless person_name.errors

    salt = SecureRandom.base64

    user = User.create(
      username: username,
      # WARNING: Consider using bcrypt (not SHA1 or SHA512) for better security
      password: Digest::SHA1.hexdigest("#{password}#{salt}"),
      salt: salt,
      person: person,
      creator: User.current.id
    )
    UserRole.create(role: Role.find(role), user: user)
    user
  end

  def self.update_user(user, params)
    # Update person name if specified
    if params.include?(:given_name) || params.include?(:family_name)
      name = user.person.names.first
      name.given_name = params[:given_name] if params[:given_name]
      name.family_name = params[:family_name] if params[:family_name]
      name.save
    end

    # Update password if any
    if params[:password]
      user.password = Digest::SHA1.hexdigest "#{params[:password]}#{user.salt}"
      user.save
    end

    # Update role if any
    if params[:role]
      role = Role.find(params[:role])
      user.roles.delete_all # Should we be appending not replacing?
      UserRole.create(role: role, user: user)
    end

    user
  end

  def self.new_authentication_token(user)
    token = create_token
    expires = Time.now + AUTHENTICATION_TOKEN_VALIDITY_PERIOD

    user.authentication_token = token
    user.token_expiry_time = expires
    user.save

    { token: token, expiry_time: expires }
  end

  def self.create_token
    # ASIDE: Are we guaranteed that this algorithm produces next to
    # no collisions? Verification of these tokens right now simply
    # involves a look up in the database thus these tokens must
    # at the very least be guaranteed to always be unique.
    # TODO: Look up standard library package 'securerandom' for
    # something we could use here with lim(collisions) -> 0.
    token_chars = ('a'..'z').to_a + ('A'..'Z').to_a + ('0'..'9').to_a
    token_length = 12
    Array.new(token_length) { token_chars[rand(token_chars.length)] }.join
  end

  def self.set_token(username, token, expiry_time)
    u = User.where(username: username).first
    if u.present?
      u.authentication_token = token
      u.token_expiry_time    = expiry_time
      u.save
    end
  end

  def self.authenticate(token)
    user = User.where(authentication_token: token).first

    return nil if user.nil? || user.token_expiry_time < Time.now

    user
  end

  def self.login(username, password)
    user = User.where(username: username).first
    unless user && \
           (bart_authenticate(user, password) || \
            new_arch_authenticate(user, password))
      return nil
    end
    new_authentication_token user
  end

  # Tries to authenticate user using the classical BART mode
  def self.bart_authenticate(user, password)
    Digest::SHA1.hexdigest("#{password}#{user.salt}") == user.password
  end

  # Tries to authenticate user using the new architecture mode
  #
  # NOTE: It's not been established what this model will be but
  # currently SHA512 is being used it seems, so we going with
  # that.
  def self.new_arch_authenticate(user, password)
    Digest::SHA512.hexdigest("#{password}#{user.salt}") == user.password
  end

  def self.check_user(username)
    user = User.where(username: username).first
    if user
      return true
    else
      return false
    end
  end

  def self.re_authenticate(username, password)
    user = User.where(username: username).first
    token = create_token
    expiry_time = compute_expiry_time
    if user
      salt = user.salt
      if Digest::SHA1.hexdigest("#{password}#{salt}") == user.password	||
         Digest::SHA512.hexdigest("#{password}#{salt}") == user.password

        User.update(user.id, authentication_token: token, token_expiry_time: expiry_time[:expiry_time])
        return { token: token, expiry_time: expiry_time[:expiry_time] }
      else
        return false
      end
    else
      return false
    end
  end
end
