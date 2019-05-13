# frozen_string_literal: true

# Utility methods for dealing with ActiveSupport::Parameters objects.
module ParameterUtils
  # Fetches field from ActiveSupport::Parameters.
  #
  # This method is just a wrapper around the fetch or raise bad request
  # routine for retrieving parameter values.
  #
  # @throws InvalidParameterError - When field is not found in stock_obs
  def fetch_parameter(parameters, field)
    value = parameters[field]

    unless value
      raise InvalidParameterError, "`#{field}` not found in parameters: #{parameters.to_json}"
    end

    value
  end
end
