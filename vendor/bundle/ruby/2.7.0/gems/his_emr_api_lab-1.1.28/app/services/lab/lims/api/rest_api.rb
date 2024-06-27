# frozen_string_literal: true

class Lab::Lims::Api::RestApi
  class LimsApiError < GatewayError; end

  class AuthenticationTokenExpired < LimsApiError; end

  class InvalidParameters < LimsApiError; end

  def initialize(config)
    @config = config
  end

  def create_order(order_dto)
    response = in_authenticated_session do |headers|
      Rails.logger.info("Pushing order ##{order_dto[:tracking_number]} to LIMS")

      if order_dto['sample_type'].casecmp?('not_specified')
        RestClient.post(expand_uri('request_order', api_version: 'v2'), make_create_params(order_dto), headers)
      else
        RestClient.post(expand_uri('create_order'), make_create_params(order_dto), headers)
      end
    end

    data = JSON.parse(response.body)
    update_order_results(order_dto) unless data['message'].casecmp?('Order already available')

    ActiveSupport::HashWithIndifferentAccess.new(
      id: order_dto.fetch(:_id, order_dto[:tracking_number]),
      rev: 0,
      tracking_number: order_dto[:tracking_number]
    )
  end

  def acknowledge(acknowledgement_dto)
    Rails.logger.info("Acknowledging order ##{acknowledgement_dto} in LIMS")
    response = in_authenticated_session do |headers|
      RestClient.post(expand_uri('/acknowledge/test/results/recipient'), acknowledgement_dto, headers)
    end
    Rails.logger.info("Acknowledged order ##{acknowledgement_dto} in LIMS. Response: #{response}")
    JSON.parse(response)
  end

  def update_order(_id, order_dto)
    in_authenticated_session do |headers|
      RestClient.post(expand_uri('update_order'), make_update_params(order_dto), headers)
    end

    update_order_results(order_dto)

    { tracking_number: order_dto[:tracking_number] }
  end

  def consume_orders(*_args, patient_id: nil, **_kwargs)
    orders_pending_updates(patient_id).each do |order|
      order_dto = Lab::Lims::OrderSerializer.serialize_order(order)

      if order_dto['priority'].nil? || order_dto['sample_type'].casecmp?('not_specified')
        patch_order_dto_with_lims_order!(order_dto, find_lims_order(order.accession_number))
      end

      if order_dto['test_results'].empty?
        begin
          patch_order_dto_with_lims_results!(order_dto, find_lims_results(order.accession_number))
        rescue InvalidParameters => e # LIMS responds with a 401 when a result is not found :(
          Rails.logger.error("Failed to fetch results for ##{order.accession_number}: #{e.message}")
        end
      end

      yield order_dto, OpenStruct.new(last_seq: 0)
    rescue LimsApiError => e
      Rails.logger.error("Failed to fetch updates for ##{order.accession_number}: #{e.class} - #{e.message}")
      sleep(1)
    end
  end

  def delete_order(_id, order_dto)
    tracking_number = order_dto.fetch('tracking_number')

    order_dto['tests'].each do |test|
      Rails.logger.info("Voiding test '#{test}' (#{tracking_number}) in LIMS")
      in_authenticated_session do |headers|
        date_voided, voided_status = find_test_status(order_dto, test, 'Voided')
        params = make_void_test_params(tracking_number, test, voided_status['updated_by'], date_voided)
        RestClient.post(expand_uri('update_test'), params, headers)
      end
    end
  end

  private

  attr_reader :config

  MAX_LIMS_RETRIES = 5 # LIMS API Calls can only fail this number of times before we give up on it

  ##
  # Execute LIMS API calls within an authenticated session.
  #
  # Method automatically checks authenticates with LIMS if necessary and passes
  # down the necessary headers for authentication to the REST call being made.
  #
  # Example:
  #
  #   response = in_authenticated_session do |headers|
  #     RestClient.get(expand_uri('query_results_by_tracking_number/XXXXXX'), headers)
  #   end
  #
  #   pp JSON.parse(response.body) if response.code == 200
  def in_authenticated_session
    retries ||= MAX_LIMS_RETRIES

    self.authentication_token = authenticate unless authentication_token

    response = yield 'token' => authentication_token, 'Content-type' => 'application/json'
    check_response!(response)
  rescue AuthenticationTokenExpired => e
    self.authentication_token = nil
    retry if (retries -= 1).positive?
  rescue RestClient::ExceptionWithResponse => e
    Rails.logger.error("LIMS Error: #{e.response&.code} - #{e.response&.body}")
    raise e unless e.response&.code == 401

    self.authentication_token = nil
    retry if (retries -= 1).positive?
  end

  def authenticate
    username = config.fetch(:username)
    password = config.fetch(:password)

    Rails.logger.debug("Authenticating with LIMS as: #{username}")
    response = RestClient.get(expand_uri("re_authenticate/#{username}/#{password}"),
                              headers: { 'Content-type' => 'application/json' })
    response_body = JSON.parse(response.body)

    if response_body['status'] == 401
      Rails.logger.error("Failed to authenticate with LIMS as #{config.fetch(:username)}: #{response_body['message']}")
      raise LimsApiError, 'LIMS authentication failed'
    end

    response_body['data']['token']
  end

  def authentication_token=(token)
    Thread.current[:lims_authentication_token] = token
  end

  def authentication_token
    Thread.current[:lims_authentication_token]
  end

  ##
  # Examines a response from LIMS to check if token has expired.
  #
  # LIMS' doesn't properly use HTTP status codes; the codes are embedded in the
  # response body. 200 is used for success responses and 401 for everything else.
  # We have this work around to examine the response body and
  # throw errors accordingly. The following are the errors thrown:
  #
  #   Lims::AuthenticationTokenExpired
  #   Lims::InvalidParameters
  #   Lims::ApiError - Thrown when we couldn't make sense of the error
  def check_response!(response)
    body = JSON.parse(response.body)
    return response if body['status'] == 200

    Rails.logger.error("Lims Api Error: #{response.body}")

    raise LimsApiError, "#{body['status']} - #{body['message']}" if body['status'] != 401

    if body['message'].match?(/token expired/i)
      raise AuthenticationTokenExpired, "Authentication token expired: #{body['message']}"
    end

    raise InvalidParameters, body['message']
  end

  ##
  # Takes a LIMS API relative URI and converts it to a full URL.
  def expand_uri(uri, api_version: 'v1')
    protocol = config.fetch(:protocol)
    host = config.fetch(:host)
    port = config.fetch(:port)
    uri = uri.gsub(%r{^/+}, '')

    "#{protocol}://#{host}:#{port}/api/#{api_version}/#{uri}"
  end

  ##
  # Converts an OrderDTO to parameters for POST /create_order
  def make_create_params(order_dto)
    {
      tracking_number: order_dto.fetch(:tracking_number),
      district: current_district,
      health_facility_name: order_dto.fetch(:sending_facility),
      first_name: order_dto.fetch(:patient).fetch(:first_name),
      last_name: order_dto.fetch(:patient).fetch(:last_name),
      phone_number: order_dto.fetch(:patient).fetch(:phone_number),
      gender: order_dto.fetch(:patient).fetch(:gender),
      arv_number: order_dto.fetch(:patient).fetch(:arv_number),
      art_regimen: order_dto.fetch(:patient).fetch(:art_regimen),
      art_start_date: order_dto.fetch(:patient).fetch(:art_start_date),
      date_of_birth: order_dto.fetch(:patient).fetch(:dob),
      national_patient_id: order_dto.fetch(:patient).fetch(:id),
      requesting_clinician: requesting_clinician(order_dto),
      sample_type: order_dto.fetch(:sample_type),
      tests: order_dto.fetch(:tests),
      date_sample_drawn: sample_drawn_date(order_dto),
      sample_priority: order_dto.fetch(:priority) || 'Routine',
      sample_status: order_dto.fetch(:sample_status),
      target_lab: order_dto.fetch(:receiving_facility),
      order_location: order_dto.fetch(:order_location) || 'Unknown',
      who_order_test_first_name: order_dto.fetch(:who_order_test).fetch(:first_name),
      who_order_test_last_name: order_dto.fetch(:who_order_test).fetch(:last_name)
    }
  end

  ##
  # Converts an OrderDTO to parameters for POST /update_order
  def make_update_params(order_dto)
    date_updated, status = sample_drawn_status(order_dto)

    {
      tracking_number: order_dto.fetch(:tracking_number),
      who_updated: status.fetch(:updated_by),
      date_updated: date_updated,
      specimen_type: order_dto.fetch(:sample_type),
      status: 'specimen_collected'
    }
  end

  def current_district
    health_centre = Location.current_health_center
    raise 'Current health centre not set' unless health_centre

    district = health_centre.district || Lab::Lims::Config.application['district']

    unless district
      health_centre_name = "##{health_centre.id} - #{health_centre.name}"
      raise "Current health centre district not set: #{health_centre_name}"
    end

    district
  end

  ##
  # Extracts sample drawn status from an OrderDTO
  def sample_drawn_status(order_dto)
    order_dto[:sample_statuses].each do |trail_entry|
      date, status = trail_entry.each_pair.find { |_date, status| status['status'].casecmp?('Drawn') }
      next unless date

      return Date.strptime(date, '%Y%m%d%H%M%S').strftime('%Y-%m-%d'), status
    end

    [order_dto['date_created'], nil]
  end

  ##
  # Extracts a sample drawn date from a LIMS OrderDTO.
  def sample_drawn_date(order_dto)
    sample_drawn_status(order_dto).first
  end

  ##
  # Extracts the requesting clinician from a LIMS OrderDTO
  def requesting_clinician(order_dto)
    orderer = order_dto[:who_order_test]

    "#{orderer[:first_name]} #{orderer[:last_name]}"
  end

  def find_lims_order(tracking_number)
    response = in_authenticated_session do |headers|
      Rails.logger.info("Fetching order ##{tracking_number}")
      RestClient.get(expand_uri("query_order_by_tracking_number/#{tracking_number}"), headers)
    end

    Rails.logger.info("Order ##{tracking_number} found... Parsing...")
    JSON.parse(response).fetch('data')
  end

  def find_lims_results(tracking_number)
    response = in_authenticated_session do |headers|
      Rails.logger.info("Fetching results for order ##{tracking_number}")
      RestClient.get(expand_uri("query_results_by_tracking_number/#{tracking_number}"), headers)
    end

    Rails.logger.info("Result for order ##{tracking_number} found... Parsing...")
    JSON.parse(response).fetch('data').fetch('results')
  end

  ##
  # Make a copy of the order_dto with the results from LIMS parsed
  # and appended to it.
  def patch_order_dto_with_lims_results!(order_dto, results)
    order_dto.merge!(
      '_id' => order_dto[:tracking_number],
      '_rev' => 0,
      'test_results' => results.each_with_object({}) do |result, formatted_results|
        test_name, measures = result
        result_date = measures.delete('result_date')

        formatted_results[test_name] = {
          results: measures.each_with_object({}) do |measure, processed_measures|
            processed_measures[measure[0]] = { 'result_value' => measure[1] }
          end,
          result_date: result_date,
          result_entered_by: {}
        }
      end
    )
  end

  def patch_order_dto_with_lims_order!(order_dto, lims_order)
    order_dto.merge!(
      'sample_type' => lims_order['other']['sample_type'],
      'sample_status' => lims_order['other']['specimen_status'],
      'priority' => lims_order['other']['priority']
    )
  end

  def update_order_results(order_dto)
    return nil if order_dto['test_results'].nil? || order_dto['test_results'].empty?

    order_dto['test_results'].each do |test_name, results|
      Rails.logger.info("Pushing result for order ##{order_dto['tracking_number']}")
      in_authenticated_session do |headers|
        params = make_update_test_params(order_dto['tracking_number'], test_name, results)

        RestClient.post(expand_uri('update_test'), params, headers)
      end
    end
  end

  def make_update_test_params(tracking_number, test_name, results, test_status = 'Drawn')
    {
      tracking_number: tracking_number,
      test_name: test_name,
      result_date: results['result_date'],
      time_updated: results['result_date'],
      who_updated: {
        first_name: results[:result_entered_by][:first_name],
        last_name: results[:result_entered_by][:last_name],
        id_number: results[:result_entered_by][:id]
      },
      test_status: test_status,
      results: results['results']&.each_with_object({}) do |measure, formatted_results|
        measure_name, measure_value = measure

        formatted_results[measure_name] = measure_value['result_value']
      end
    }
  end

  def find_test_status(order_dto, target_test, target_status)
    order_dto['test_statuses'].each do |test, statuses|
      next unless test.casecmp?(target_test)

      statuses.each do |date, status|
        next unless status['status'].casecmp?(target_status)

        return [Date.strptime(date, '%Y%m%d%H%M%S'), status]
      end
    end

    nil
  end

  def make_void_test_params(tracking_number, test_name, voided_by, void_date = nil)
    void_date ||= Time.now

    {
      tracking_number: tracking_number,
      test_name: test_name,
      time_updated: void_date,
      who_updated: {
        first_name: voided_by[:first_name],
        last_name: voided_by[:last_name],
        id_number: voided_by[:id]
      },
      test_status: 'voided'
    }
  end

  def orders_pending_updates(patient_id = nil)
    Rails.logger.info('Looking for orders that need to be updated...')
    orders = {}

    orders_without_specimen(patient_id).each { |order| orders[order.order_id] = order }
    orders_without_results(patient_id).each { |order| orders[order.order_id] = order }
    orders_without_reason(patient_id).each { |order| orders[order.order_id] = order }

    orders.values
  end

  def orders_without_specimen(patient_id = nil)
    Rails.logger.debug('Looking for orders without a specimen')
    unknown_specimen = ConceptName.where(name: Lab::Metadata::UNKNOWN_SPECIMEN)
                                  .select(:concept_id)
    orders = Lab::LabOrder.where(concept_id: unknown_specimen)
                          .where.not(accession_number: Lab::LimsOrderMapping.select(:lims_id))
    orders = orders.where(patient_id: patient_id) if patient_id

    orders
  end

  def orders_without_results(patient_id = nil)
    Rails.logger.debug('Looking for orders without a result')
    # Lab::OrdersSearchService.find_orders_without_results(patient_id: patient_id)
    #                         .where.not(accession_number: Lab::LimsOrderMapping.select(:lims_id).where("pulled_at IS NULL"))
    Lab::OrdersSearchService.find_orders_without_results(patient_id: patient_id)
                             .where(order_id: Lab::LimsOrderMapping.select(:order_id))
  end

  def orders_without_reason(patient_id = nil)
    Rails.logger.debug('Looking for orders without a reason for test')
    orders = Lab::LabOrder.joins(:reason_for_test)
                          .merge(Observation.where(value_coded: nil, value_text: nil))
                          .limit(1000)
                          .where.not(accession_number: Lab::LimsOrderMapping.select(:lims_id))
    orders = orders.where(patient_id: patient_id) if patient_id

    orders
  end
end
