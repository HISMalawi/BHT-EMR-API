# frozen_string_literal: true

require 'logger'
require 'securerandom'
require 'digest'

require_relative 'person_service'

module UserService

  module CustomBase62
    CHARS = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz".freeze
    BASE = CHARS.length

    def self.decode(str)
      str.chars.reduce(0) { |num, char| num * BASE + CHARS.index(char) }
    end
  end

  AUTHENTICATION_TOKEN_VALIDITY_PERIOD = 24.hours
  LOGGER = Logger.new $stdout

  ALPHABET = ('a'..'z').to_a + ('0'..'9').to_a + ['/']
  CHAR_TO_INT = ALPHABET.each_with_index.to_h
  INT_TO_CHAR = CHAR_TO_INT.invert
  BASE_TIME = Time.now.to_i

  class UserCreateError < StandardError; end
  class UserUpdateError < InvalidParameterError; end

  def self.find_users(role: nil)
    query = User.all
    query = User.joins(:roles).where(user_role: { role: }) if role
    query
  end

  def self.create_user(username:, password:, given_name:, family_name:, roles:, programs:)
    person = person_service.create_person(
      birthdate: nil, birthdate_estimated: false, gender: nil
    )
    raise UserCreateError, "Person: #{person.errors}" unless person.errors.empty?

    person_service.create_person_name(
      person, given_name:, family_name:
    )
    raise UserCreateError, "Person: #{person.errors}" unless person.errors.empty?

    salt = SecureRandom.base64

    user = User.create(
      username:,
      # WARNING: Consider using bcrypt (not SHA1 or SHA512) for better security
      password: Digest::SHA1.hexdigest("#{password}#{salt}"),
      salt:,
      person:,
      creator: User.current.id
    )
    roles.each do |rolename|
      role = Role.find rolename
      UserRole.create role:, user:
    end
    # user programs
    programs&.each do |program_id|
      UserProgram.create user_id: user.user_id, program_id:
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
    if params[:roles].respond_to?(:each)
      user.user_roles.destroy_all unless params[:must_append_roles]
      params[:roles].each do |rolename|
        role = Role.find rolename
        UserRole.create role:, user:
      end
    end

    # Update programs if any
    if params.include?(:programs)
      user.user_programs.destroy_all
      params[:programs].each do |program|
        UserProgram.create user_id: user.user_id, program_id: program
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

    { token:, expiry_time: expires, user: }
  rescue StandardError => e
    Rails.logger.error "Error creating authentication token: #{e}"
    Rails.logger.error e.backtrace.join("\n")
    raise e
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
    u = User.where(username:).first
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
    user = User.where(username:).first
    unless user&.active? && \
           (bart_authenticate(user, password) || \
            new_arch_authenticate(user, password))
      return nil
    end

    new_authentication_token user
  rescue StandardError => e
    Rails.logger.error "Error logging in: #{e}"
    Rails.logger.error e.backtrace.join("\n")
    raise e
  end

  def self.reset_password(code:)
    secret_key =  YAML.safe_load(File.read('config/application.yml'))['password_reset']['secret_key']

    raise InvalidParameterError, 'Code is required' unless code.present?

    #  {:generated_at=>\"kn/gb/xk/rrds/1800385256\", :expires_at=>1800471656}:Hash
    decrypted = decrypt_from_code(code, secret_key)
    
    values = decrypted[:generated_at].split('/')

    expires = decrypted[:expires_at]

    raise InvalidParameterError, 'Invalid code' unless values.size == 5

    fname, lname, username, location_id = values

    # Check if the code is valid
    raise InvalidParameterError, 'Invalid code, missing attributes' unless [fname, lname, username, location_id].all? { |v| v.present? }
    
    # Check if the location is valid
    raise InvalidParameterError, 'Location in code does not match user' unless Location.current.id.to_i == location_id.to_i


    # Check if the code is expired
    raise InvalidParameterError, 'Code Expired' if Time.now.to_i > expires.to_i

    # Check if the user exists
    # example values: sr/ur/an/1/7003728
    # first and last letters of the first and last name, location_id then expiry time
    user = User.joins(person: :names)
      .where("person_name.given_name LIKE '#{fname[0]}%' AND person_name.given_name LIKE '%#{fname[1]}'")
      .where("person_name.family_name LIKE '#{lname[0]}%' AND person_name.family_name LIKE '%#{lname[1]}'")
      .where("username LIKE '#{username[0]}%' AND username LIKE '%#{username[1]}'").first

    raise NotFoundError, 'User Not Found' unless user

    # Check if the user is active
    raise InvalidParameterError, 'User is not active' unless user.active?

    # auto expire user password
    UserProperty.where(
      user_id: user.id,
      property: 'last_password_reset'
    ).update_all(property_value: 31.days.ago.to_date)

    # authenticate the user
    new_authentication_token(user)
  end

  def self.string_to_int(str, max_chars)
    str = str.downcase[0, max_chars].ljust(max_chars, 'a')
    result = 0
    str.chars.each_with_index do |char, i|
      result += (CHAR_TO_INT[char] || 0) * (36 ** (max_chars - 1 - i))
    end
    result
  end

  def self.int_to_string(num, max_chars)
    result = ''
    temp = num
    max_chars.times do |i|
      power = max_chars - 1 - i
      char_idx = (temp / (36 ** power)) % 36
      result += INT_TO_CHAR[char_idx]
      temp -= char_idx * (36 ** power)
    end
    result
  end

  def self.derive_key(secret_key)
    key = Digest::SHA256.hexdigest(secret_key).to_i(16) & 0x3FFFFFFFFFFFF
    key
  end

  def self.decrypt_from_code(received_code, secret_key)
    key = derive_key(secret_key)
    obfuscated = CustomBase62.decode(received_code)
    packed = obfuscated ^ key

    fname = int_to_string(packed >> (26 + 10 + 10 + 10), 2)
    lname = int_to_string((packed >> (26 + 10 + 10)) & 0x3FF, 2)
    username = int_to_string((packed >> (26 + 10)) & 0x3FF, 2)
    location_id = ((packed >> 26) & 0x3FF).to_s
    timestamp = (packed & 0x3FFFFFF)
    timestamp = timestamp - 0x4000000 if timestamp >= 0x2000000
    generation_time = timestamp + (Time.now.to_i + 24 * 60 * 60)
    expiration_time = generation_time + 24 * 60 * 60

    original_data = "#{fname}/#{lname}/#{username}/#{location_id}/#{generation_time}"

    puts "Received Code: #{received_code}"
    puts "Decompressed Data (Generated At): #{original_data}"
    puts "Expiration Time: #{expiration_time} (#{Time.at(expiration_time).strftime('%I:%M %p')})"

    { generated_at: original_data, expires_at: expiration_time }
  rescue StandardError => e
    { error: "Decryption failed: #{e.message}" }
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
    !User.where(username:).empty?
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

  # check if user is already assigned to a project
  def self.find_user_program(user_id, program_id)
    UserProgram.where(user_id:, program_id:).first
  end
end
