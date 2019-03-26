# frozen_string_literal: true

require 'set'

# Blesses ActiveController Controllers with a get_params method
# which is a wrapper of `params` method that is able to enforce
# the presence of some fields.
#
# Why do you need this? Well, almost all of our parameter validation
# is done at the model level (ie when saving or updating). This
# mixin is here to bail you out in cases where the params you are
# retrieving are not tied to any specific model, for example login
# params.
module RequireParams
  # A `params` wrapper that ensures that required params are present.
  #
  # @param required A list of required fields that must be present
  # @param optional A list of optional fields to be retrieved
  #
  # @return A pair in which the first item is either the params or an
  #         error object containing missing fields and a boolean which
  #         is true if there are missing fields
  #
  # NOTE: If there are no required fields calling this is the equivalent
  #       of directly calling params.permit(...).
  #       ie get_params(fields: [...]) == params(*[...])
  def required_params(required: [], optional: [])
    required = Set.new required
    all_fields = required + optional
    all_params = params.permit(*all_fields)
    missing_params = collect_missing_parameters all_params, required, all_fields
    Rails.logger.debug "missing params: #{missing_params}"
    if missing_params.empty?
      [all_params, false]
    else
      [missing_params, true]
    end
  end

  private

  def collect_missing_parameters(parameters, required, all)
    required.each_with_object({}) do |field, missing_params|
      missing_params[field] = 'Field is required' unless parameters[field] || all.include?(field)
    end
  end
end
