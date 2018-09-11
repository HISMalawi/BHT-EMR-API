# frozen_string_literal: true

require 'require_params'

class ApplicationController < ActionController::API
  before_action :authenticate

  protected

  include RequireParams

  DEFAULT_PAGE_SIZE = 10

  def authenticate
    authentication_token = request.headers['Authorization']
    unless authentication_token
      errors = ['Authorization token required']
      render json: { errors: errors }, status: :unauthorized
      return false
    end

    user = UserService.authenticate authentication_token
    unless user
      errors = ['Invalid or expired authentication token']
      render json: { errors: errors }, status: :unauthorized
      return false
    end

    User.current = user
    true
  end

  def paginate(queryset)
    limit = (params[:page_size] || DEFAULT_PAGE_SIZE).to_i
    offset = (params[:page] || 0).to_i * DEFAULT_PAGE_SIZE

    queryset.offset(offset).limit(limit)
  end

  # Takes district search filters and converts to expression containing
  # inexact glob matchers that can be passed to `where` expressins.
  def make_inexact_filters(filters, fields=nil)
    fields = filters.keys unless fields

    inexact_filters = filters.to_hash.each_with_object([[], []]) do |kv_pair, inexact_filters|
      k, v = kv_pair

      logger.debug kv_pair

      if fields.include? k.to_sym
        inexact_filters[0] << "#{k} like ?"
        inexact_filters[1] << "%#{v}%"
      else
        inexact_filters[0] << "#{k} = ?"
        inexact_filters[1] << v
      end
    end
    logger.debug inexact_filters
    [inexact_filters[0].join(' AND ')] + inexact_filters[1]
  end
end
