# frozen_string_literal: true

require 'cgi'
require 'couchrest'

##
# A CouchRest wrapper for the changes API.
#
# See: https://github.com/couchrest/couchrest
class CouchBum
  cattr_accessor :logger

  def initialize(database:, protocol: 'http', host: 'localhost', port: 5984, username: nil, password: nil)
    @connection_string = make_connection_string(protocol, username, password, host, port, database)

    CouchBum.logger ||= Logger.new(STDOUT)
  end

  ##
  # Attaches to the Changes API and streams the updates to passed block.
  #
  # This is a blocking call that only stops when there are no more
  # changes to pull or is explicitly terminated by calling +choke+
  # within the passed block.
  def binge_changes(since: 0, limit: nil, include_docs: nil, &block)
    catch(:choke) do
      logger.debug("Binging #{limit} changes from '#{since}'")
      params = stringify_params(limit: limit, include_docs: include_docs)
      params = "since=#{since}&#{params}" unless since.blank?

      changes = couch_rest(:get, "_changes?#{params}")
      context = BingeContext.new(changes)
      changes['results'].each do |change|
        context.current_seq = change['seq']
        context.instance_exec(change, &block)
      end
    end
  end

  def couch_rest(method, route, *args, **kwargs)
    url = expand_route(route)
    CouchRest.send(method, url, *args, **kwargs)
  rescue CouchRest::Exception => e
    logger.error("Failed to communicate with CouchDB: Status: #{e.http_code} - #{e.http_body}")
    raise e
  end

  private

  # Context under which the callback passed to binge_changes is executed.
  class BingeContext
    attr_accessor :current_seq

    def initialize(changes)
      @changes = changes
    end

    def choke
      throw :choke
    end

    def last_seq
      @changes['last_seq']
    end

    def pending
      @changes['pending']
    end
  end

  def make_connection_string(protocol, username, password, host, port, database)
    auth = username ? "#{CGI.escape(username)}:#{CGI.escape(password)}@" : ''

    "#{protocol}://#{auth}#{host}:#{port}/#{database}"
  end

  def expand_route(route)
    route = route.gsub(%r{^/+}, '')

    "#{@connection_string}/#{route}"
  end

  def stringify_params(params)
    params.reduce('') do |str_params, entry|
      name, value = entry
      next params unless value

      param = "#{name}=#{value}"
      str_params.empty? ? param : "#{str_params}&#{param}"
    end
  end
end
