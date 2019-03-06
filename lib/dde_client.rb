# frozen_string_literal: true

require 'logger'
require 'restclient'

class DDEClient
  def initialize
    @auto_login = true # If logged out, automatically login on next request
    @base_url = nil
    @connection = nil
  end

  # Connect to DDE Web Service using either a configuration file
  # or an old Connection.
  #
  # @return A Connection object that can be used to re-connect to DDE
  def connect(url:, username:, password:)
    @connection = establish_connection(url: url, username: username, password: password)
  end

  # Reconnect to DDE using previous connection
  #
  # @see: DDEClient#connect
  def restore_connection(connection)
    @connection = reload_connection(connection)
  end

  def get(resource)
    exec_request resource do |url, headers|
      RestClient.get url, headers
    end
  end

  def post(resource, data)
    exec_request resource do |url, headers|
      RestClient.post url, data.to_json, headers
    end
  end

  def put(resource, data)
    exec_request resource do |url, headers|
      RestClient.put url, data.to_json, headers
    end
  end

  def delete(resource)
    exec_request resource do |url, headers|
      RestClient.delete url, headers: headers
    end
  end

  private

  JSON_CONTENT_TYPE = 'application/json'
  LOGGER = Logger.new STDOUT
  DDE_API_KEY_VALIDITY_PERIOD = 3600 * 12
  DDE_VERSION = 'v1'

  # Reload old connection to DDE
  def reload_connection(connection)
    LOGGER.debug 'Loading DDE connection'
    if connection[:expires] < Time.now
      LOGGER.debug 'DDE connection expired'
      establish_connection(connection[:config])
    else
      @base_url = connection[:config][:url]
      connection
    end
  end

  # Establish a connection to DDE
  #
  # NOTE: This simply involves logging into DDE
  def establish_connection(url:, username:, password:)
    LOGGER.debug 'Establishing new connection to DDE from configuration'

    # Block any automatic logins when processing request to avoid infinite loop
    # in request execution below... Under normal circumstances request execution
    # will attempt a login if 401 is met. Not pretty, I know but it does the job
    # for now!!!
    @auto_login = false

    # HACK: Globally save base_url as a connection object may not currently
    # be available to the build_url method right now
    @base_url = url

    response, status = post('login', username: username, password: password)

    @auto_login = true

    if status != 200
      raise DDEClientError, "Unable to establish connection to DDE: #{response}"
    end

    LOGGER.info('Connection to DDE established :)')
    @connection = {
      key: response['access_token'],
      expires: Time.now + DDE_API_KEY_VALIDITY_PERIOD,
      config: { url: url, username: username, password: password }
    }
  end

  # Returns a URI object with API host attached
  def build_uri(resource)
    "#{@base_url}/#{DDE_VERSION}/#{resource}"
  end

  def headers
    {
      'Content-type' => JSON_CONTENT_TYPE,
      'Authorization' => @connection ? @connection[:key] : nil
    }
  end

  def exec_request(resource)
    LOGGER.debug "Executing DDE request (#{resource})"
    response = yield build_uri(resource), headers
    LOGGER.debug "Handling DDE response:\n\tStatus - #{response.code}\n\tBody - #{response.body}"
    handle_response response
  rescue RestClient::Unauthorized => e
    LOGGER.error "DDEClient suppressed exception: #{e}"
    return handle_response e.response unless @auto_login

    LOGGER.debug 'Auto-logging into DDE...'
    establish_connection(@connection[:config])
    LOGGER.debug "Reset connection: #{@connection}"
    retry # Retry last request...
  rescue RestClient::BadRequest => e
    LOGGER.error "DDEClient suppressed exception: #{e}"
    handle_response e.response
  end

  def handle_response(response)
    # 204 is no content response, no further processing required.
    return nil, 204 if response.code.to_i == 204

    # NOTE: Following is commented out as DDE at the moment is quite liberal
    # in how it responds to various requests. It seems to know no difference
    # between 'application/json' and 'text/plain'.
    #
    # unless response["content-type"].include? JSON_CONTENT_TYPE
    #   puts "Invalid response from API: content-type: " + response["content-type"]
    #   return nil, 0
    # end

    # DDE is somewhat undecided on how it reports back its status code.
    # Sometimes we get a proper HTTP status code and sometimes it is within
    # the response body.
    response_status = response.body['status'] || response.code

    [JSON.parse(response.body), response_status&.to_i]
  end
end
