# frozen_string_literal: true

require 'logger'
require 'net/http'

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
  def connect(config: nil, connection: nil)
    raise ArgumentError, 'config or connection required' unless config || connection
    @connection = reload_connection connection if connection
    @connection = establish_connection config if config && !@connection
    @connection
  end

  def get(resource)
    uri = build_uri resource
    request = Net::HTTP::Get.new(uri)
    prepare_request request
    exec_request request, uri
  end

  def post(resource, data)
    uri = build_uri resource
    LOGGER.debug uri
    request = Net::HTTP::Post.new(uri)
    prepare_request request
    request['Content-type'] = JSON_CONTENT_TYPE
    request.body = JSON.dump(data)
    exec_request request, uri
  end

  def put(resource, data)
    uri = build_uri resource
    request = Net::HTTP::Put.new(uri)
    prepare_request request
    request['Content-type'] = JSON_CONTENT_TYPE
    request.body = JSON.dump(data)
    exec_request request, uri
  end

  def delete(resource)
    uri = build_uri resource
    request = Net::HTTP::Delete.new(uri)
    prepare_request request
    exec_request request, uri
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
      establish_connection connection[:config]
    else
      # HACK: Globally save base_url as a connection object may not currently
      # be available to the expand_url method right now
      @base_url = connection[:config][:base_url]
      connection
    end
  end

  # Establish a connection to DDE using config
  #
  # NOTE: This simply involves logging into DDE
  def establish_connection(config)
    LOGGER.debug 'Establishing new connection to DDE from configuration'

    # Block any automatic logins when processing request to avoid infinite loop
    # in request execution below... Under normal circumstances request execution
    # will attempt a login if 404 is met. Not pretty, I know but it does the job
    # for now!!!
    @auto_login = false

    # HACK: Globally save base_url as a connection object may not currently
    # be available to the expand_url method right now
    @base_url = config[:base_url]

    response, status = post 'login', {
      username: config[:username],
      password: config[:password]
    }

    @auto_login = true

    raise 'Unable to establish connection to DDE :(' if status != 200

    LOGGER.info 'Connection to DDE established :)'

    # Return our connection object...
    {
      key: response['access_token'],
      expires: Time.now + DDE_API_KEY_VALIDITY_PERIOD,
      config: config
    }
  end

  # Returns a URI object with API host attached
  def build_uri(resource)
    URI("#{@base_url}/#{DDE_VERSION}/#{resource}")
  end

  # This just sets the API key
  def prepare_request(request)
    authorization = @connection[:key] if @connection
    request['Authorization'] = @connection[:key] if authorization
    request
  end

  def exec_request(request, uri, ignore_auto_login = false)
    response = Net::HTTP.start(uri.hostname, uri.port) do |http|
      LOGGER.debug 'Making a request to DDE API @ ' + uri.to_s
      http.request(request)
    end

    LOGGER.debug "Handling DDE response:\n\tStatus - #{response.code}\n\tBody - #{response.body}"

    status = response.code.to_i

    if status == 401 && @auto_login && !ignore_auto_login
      LOGGER.debug 'Auto-logging into DDE...'
      @connection[:key] = nil
      new_connection = establish_connection @connection[:config]
      return { 'error' => 'Failed to login into DDE' }, 401 unless new_connection
      @connection = new_connection
      # Login successful, lets retry the last request and make sure we
      # don't retry an auto-login
      exec_request(request, uri, true)
    end

    handle_response response
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

    [JSON.parse(response.body), response.code.to_i]
  rescue JSON::ParserError, StandardError => e
    # NOTE: Catch all as Net::HTTP throws a plethora of exceptions whose
    # sole relationship derives from they being derivatives of StandardError.
    LOGGER.error "Failed to communicate with DDE: #{e}"
    [nil, 0]
  end
end
