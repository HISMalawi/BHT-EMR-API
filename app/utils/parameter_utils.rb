# frozen_string_literal: true

require 'logger'

# Utility methods for dealing with ActiveSupport::Parameters objects.
module ParameterUtils
  LOGGER = Logger.new($stdout)

  # Fetches field from ActiveSupport::Parameters.
  #
  # This method is just a wrapper around the fetch or raise bad request
  # routine for retrieving parameter values.
  #
  # @throws InvalidParameterError - When field is not found in stock_obs
  def fetch_parameter(parameters, field)
    parameters.fetch(field)
  rescue KeyError => e
    LOGGER.error("Failed to fetch parameter `#{field}` due to #{e}")
    raise InvalidParameterError, "`#{field}` not found in parameters: #{parameters.to_json}"
  end

  def fetch_parameter_as_date(parameters, field, default = nil)
    parameters.fetch(field, default)&.to_date
  rescue ArgumentError => e
    LOGGER.error("Failed to fetch parameter `#{field}` due to #{e}")
    raise InvalidParameterError, "Could not parse #{field} as date from: #{parameters.to_json}"
  end
end
