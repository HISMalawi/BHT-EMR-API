# frozen_string_literal: true

module Lab
  # This class is used to encode and decode the JWT token
  module JsonWebTokenService
    class << self
      SECRET_KEY = Rails.application.secrets.secret_key_base.to_s

      def encode(payload, request_ip, exp = 18.hours.from_now)
        payload[:exp] = exp.to_i
        JWT.encode(payload, SECRET_KEY + request_ip)
      end

      def decode(token, request_ip)
        decoded = JWT.decode(token, SECRET_KEY + request_ip)[0]
        HashWithIndifferentAccess.new decoded
      end
    end
  end
end
