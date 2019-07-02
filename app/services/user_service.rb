# frozen_string_literal: true

require 'logger'
require 'securerandom'

require_relative 'person_service'

module UserService
  AUTHENTICATION_TOKEN_VALIDITY_PERIOD = 24.hours
  LOGGER = Logger.new STDOUT

  class UserCreateError < StandardError; end

  def self.find_users(role: nil)
    query = User.all
    query = User.joins(:roles).where(user_role: { role: role }) if role
    query
  end

  def self.create_user(username:, password:, given_name:, family_name:, roles:, programs:)
    person = person_service.create_person(
      birthdate: nil, birthdate_estimated: false, gender: nil
    )
    raise UserCreateError, "Person: #{person.errors}" unless person.errors.empty?

    person_service.create_person_name(
      person, given_name: given_name, family_name: family_name
    )
    raise UserCreateError, "Person: #{person.errors}" unless person.errors.empty?

    salt = SecureRandom.base64

    user = User.create(
      username: username,
      # WARNING: Consider using bcrypt (not SHA1 or SHA512) for better security
      password: Digest::SHA1.hexdigest("#{password}#{salt}"),
      salt: salt,
      person: person,
      creator: User.current.id
    )
    roles.each do |rolename|
      role = Role.find rolename
      UserRole.create role: role, user: user
    end
    #user programs
    programs&.each do |program_id|
      user_programs = UserProgram.create user_id: user.user_id, program_id: program_id
    end

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

    # Update roles if any
    if params[:roles]&.respond_to?(:each)
      user.user_roles.destroy_all unless params[:must_append_roles]
      params[:roles].each do |rolename|
        role = Role.find rolename
        UserRole.create role: role, user: user
      end
    end

    user
  end

  def self.new_authentication_token(user)
    token = create_token
    expires = Time.now + AUTHENTICATION_TOKEN_VALIDITY_PERIOD

    user.authentication_token = token
    user.token_expiry_time = expires
    user.save

    { token: token, expiry_time: expires, user: user }
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
    return unless u.present?

    u.authentication_token = token
    u.token_expiry_time    = expiry_time
    u.save
  end

  def self.authenticate(token)
    user = User.where(authentication_token: token).first

    return nil if user.nil? || user.token_expiry_time < Time.now

    user
  end

  def self.login(username, password)
    user = User.where(username: username).first
    unless user&.active? && \
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
    !User.where(username: username).empty?
  end

  def self.user_roles(user)
    user.roles
  end

  def self.activate_user(user)
    user.deactivated_on = nil
    user.save
  end

  def self.deactivate_user(user)
    user.deactivated_on = Time.now
    user.save
  end

  def self.person_service
    PersonService.new
  end

  #check if user is already assigned to a project
  def self.find_user_program(user_id, program_id)
    user_program = UserProgram.where(user_id: user_id, program_id: program_id).first
    user_program
  end

end
