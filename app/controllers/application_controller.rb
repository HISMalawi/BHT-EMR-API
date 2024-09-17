# frozen_string_literal: true

require 'require_params'
require 'user_service'

class ApplicationController < ActionController::API
  before_action :check_location
  before_action :authenticate
  after_action :refresh_dashboard, if: :refresh_dashboard_needed?
      
  protected

  include RequireParams
  include ExceptionHandler

  CURRENT_LOCATION_PROPERTY = 'current_health_center_id'
  DEFAULT_PAGE_SIZE = 10

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

  private 

  def refresh_dashboard
    ImmunizationReportJob.perform_later(1.year.ago.to_date.to_s, Date.today.to_s, User.current.location_id)
  end

  def refresh_dashboard_needed?
    patient_programs_create_action? || administer_vaccine_action? || orders_destroy_action?
  end

  def patient_programs_create_action?
    controller_name == 'patient_programs' && action_name == 'create'
  end

  def administer_vaccine_action?
    controller_name == 'administer_vaccine' && action_name == 'administer_vaccine'
  end

  def orders_destroy_action?
    controller_name == 'orders' && action_name == 'destroy'
  end

end
