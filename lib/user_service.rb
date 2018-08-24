
module UserService

	def self.create_user(params)

    password    = params[:password]
    username    = params[:username]
    cur_token       = params[:token]

    details     = compute_expiry_time
    salt        = User.random_string(10)
    gender      = params[:gender]
    birthdate   = params[:birthdate]

    creator = User.current

    person = Person.create(
        gender:    gender,
        birthdate: birthdate.to_date.to_s(:db),
        creator: creator.id
    )

    PersonName.create(
       given_name: params[:first_name],
       family_name:  params[:last_name],
        person_id: person.id,
       creator: creator.id
    )

    User.create(
        username:             username,
        password:             Digest::SHA1.hexdigest("#{password}#{salt}"),
        salt:                 salt,
        authentication_token: details[:token],
        token_expiry_time:    details[:expiry_time],
        person_id:            person.id,
        creator:              creator.id
    )

    return {token: details[:token], expiry_time: details[:expiry_time]}
	end

  def self.update_user(params)

    user = User.where(username: params[:username]).first
    if user.blank?
      return false
    end

    details           = compute_expiry_time

    person = Person.find(user.person_id)
    name   = PersonName.where(person_id: user.person_id).last

    if name.blank? || person.blank?
      return false
    end

    user.authentication_token = details[:token]
    user.token_expiry_time = details[:expiry_time]
    user.password         = Digest::SHA1.hexdigest("#{params[:password]}#{user.salt}") if params[:password].present?

    person.gender       = params[:gender] if params[:gender].present?
    person.birthdate    = params[:birthdate].to_date.to_s(:db) if params[:birthdate].present?

    name.given_name   = params[:first_name] if params[:first_name].present?
    name.family_name    = params[:last_name] if params[:last_name].present?

    user.save
    person.save
    name.save

    return true
  end

	def self.create_token
		token_chars  = ('a'..'z').to_a + ('A'..'Z').to_a + ('0'..'9').to_a
  		token_length = 12
  		token = Array.new(token_length) { token_chars[rand(token_chars.length)] }.join
		return token
	end
 

	def self.compute_expiry_time

   		token = create_token
   		time = Time.now 
   		time = time + 14400
		return {token: token, expiry_time: time.strftime("%Y%m%d%H%M%S")}
  end

  def self.set_token(username, token, expiry_time)
    u = User.where(username: username).first
    if u.present?
      u.authentication_token = token
      u.token_expiry_time    = expiry_time
      u.save
    end
  end

	def self.check_token(token)
		user = User.where(authentication_token: token).first

		if user 
			if user.token_expiry_time > Time.now.strftime("%Y%m%d%H%M%S")
				return true
			else
				return false
			end
		else
			return false
		end

	end


	def self.authenticate(username, password)

		user = User.where(username: username).first

    if user
      salt = user.salt
			if Digest::SHA1.hexdigest("#{password}#{salt}") == user.password	||
          Digest::SHA512.hexdigest("#{password}#{salt}") == user.password
				return true
			else
				return false
			end
		else
			return false
		end
	end


	def self.check_user(username)
		user = User.where(username: username).first
		if user
			return true
		else
			return false
		end

	end


	def self.re_authenticate(username,password)
		user = User.where(username: username).first
		token = create_token
		expiry_time = compute_expiry_time
		if user
      salt = user.salt
			if Digest::SHA1.hexdigest("#{password}#{salt}") == user.password	||
          Digest::SHA512.hexdigest("#{password}#{salt}") == user.password

				User.update(user.id, authentication_token: token, token_expiry_time: expiry_time[:expiry_time])
				return {token: token, expiry_time: expiry_time[:expiry_time]}
			else
				return false
			end
		else
			return false
		end

	end

end
