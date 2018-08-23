
module UserService

	def self.create_user(params)

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
