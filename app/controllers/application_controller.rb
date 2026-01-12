# frozen_string_literal: true

require 'require_params'
require 'user_service'

class ApplicationController < ActionController::API
  before_action :check_location
  before_action :authenticate
  before_action :check_client_version

  protected

  include RequireParams
  include ExceptionHandler

  CURRENT_LOCATION_PROPERTY = 'current_health_center_id'
  DEFAULT_PAGE_SIZE = 10

  # Map of clients to their allowed versions
  CLIENT_VERSION_CONFIGURATION = {
    'EMASTERCARD' => 'v2025.Q4.R0',
    'POC' => 'v2025.Q4.R0'
  }

  # Required by audited gem
  def current_user
    User.current
  end

  def check_client_version
    if params[:no_client]
      return true
    end

    client = request.headers['Client']
    client_version = request.headers['Client-Version']

    unless client
      render json: { errors: ['Unrecognized API Client'] }, status: :bad_request
      return false
    end

    unless client_version
      render json: { errors: ['Unknown API Client Version'] }, status: :bad_request
      return false
    end
    
    if CLIENT_VERSION_CONFIGURATION.key?(client)
      required_version = CLIENT_VERSION_CONFIGURATION[client]
      if !validate_frontend_versions(client_version, required_version)
        render json: { errors: ["Minimum version required is #{required_version}"], required_version: required_version }, status: :upgrade_required
        return false
      end
    end
    true
  end
  
  def validate_frontend_versions(active, target)
    to_num = ->(str) { str.gsub(/\D/, '').to_i }

    active_version_parts = active.split(".")
    target_version_parts = target.split(".")
    

    active_version_year =  to_num.call(active_version_parts[0])
    active_version_quarter = to_num.call(active_version_parts[1])
    active_version_revision = to_num.call(active_version_parts[2])

    target_version_year = to_num.call(target_version_parts[0])
    target_version_quarter = to_num.call(target_version_parts[1])
    target_version_revision = to_num.call(target_version_parts[2])

    if active_version_year < target_version_year
      return false
    end    
    
    if active_version_quarter < target_version_quarter
      return false
    end

    if active_version_revision < target_version_revision
      return false
    end

    true
  end

  def authenticate
    authentication_token = request.headers['Authorization']
    unless authentication_token
      errors = ['Authorization token required']
      render json: { errors: }, status: :unauthorized
      return false
    end

    user = UserService.authenticate authentication_token
    unless user
      errors = ['Invalid or expired authentication token']
      render json: { errors: }, status: :unauthorized
      return false
    end

    User.current = user
    true
  end

  def check_location
    location_id = GlobalProperty.where(property: CURRENT_LOCATION_PROPERTY).first.property_value
    unless location_id
      render json: { errors: ['Current location not set'] }, status: :service_unavailable
      return false
    end

    Location.current = Location.find(location_id)
    true
  end

  def paginate(queryset)
    params.permit(:paginate, :page, :page_size)
    return queryset.all if params[:paginate] == 'false'

    limit = (params[:page_size] || DEFAULT_PAGE_SIZE).to_i
    offset = ((params[:page] || 1).to_i - 1) * limit

    queryset.offset(offset).limit(limit)
  end

  def parse_date(str_date)
    Date.strptime(str_date)
  rescue ArgumentError => e
    render json: { errors: ["Failed to parse date: #{e}"] },
           status: :bad_request
    nil
  end

  def render_zpl(data)
    raw = params.delete(:raw)

    if raw && raw == true
      render json: data
      
      return
    end

    send_data data[:zpl], type: "application/label; charset=utf-8",
                   stream: false,
                   filename: "barcode-#{rand(10_000)}.lbl",
                   disposition: "inline"
  end
  # Takes search filters and converts them to an expression containing
  # inexact glob matchers that can be passed to `where` expressins.
  def make_inexact_filters(filters, fields = nil)
    fields ||= filters.keys

    inexact_filters = filters.to_hash.each_with_object([[], []]) do |kv_pair, inexact_filters|
      k, v = kv_pair

      if fields.include? k.to_sym
        inexact_filters[0] << "#{k} like ?"
        inexact_filters[1] << "%#{v}%"
      else
        inexact_filters[0] << "#{k} = ?"
        inexact_filters[1] << v
      end
    end

    [inexact_filters[0].join(' AND ')] + inexact_filters[1]
  end
end
