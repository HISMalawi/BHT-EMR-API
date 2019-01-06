# frozen_string_literal: true

# Flags bad client provided values (should trigger a 400 - bad request)
class InvalidParameterError < ApplicationError
  attr_accessor :model_errors
end
