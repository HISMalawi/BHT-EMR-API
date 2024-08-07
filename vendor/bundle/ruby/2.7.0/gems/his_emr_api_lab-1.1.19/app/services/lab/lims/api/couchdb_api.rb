# frozen_string_literal: true

require 'couch_bum/couch_bum'

require_relative '../config'

module Lab
  module Lims
    module Api
      ##
      # Talk to LIMS like a boss
      class CouchDbApi
        attr_reader :bum

        def initialize(config: nil)
          config ||= Config.couchdb

          @bum = CouchBum.new(protocol: config['protocol'],
                              host: config['host'],
                              port: config['port'],
                              database: "#{config['prefix']}_order_#{config['suffix']}",
                              username: config['username'],
                              password: config['password'])
        end

        ##
        # Consume orders from the LIMS queue.
        #
        # Retrieves orders from the LIMS queue and passes each order to
        # given block until the queue is empty or connection is terminated
        # by calling method +choke+.
        def consume_orders(from: 0, limit: 30)
          bum.binge_changes(since: from, limit: limit, include_docs: true) do |change|
            next unless change['doc']['type']&.casecmp?('Order')

            yield OrderDTO.new(change['doc']), self
          end
        end

        def create_order(order)
          order = order.dup
          order.delete('_id')

          bum.couch_rest :post, '/', order
        end

        def update_order(id, order)
          bum.couch_rest :put, "/#{id}", order
        end
      end
    end
  end
end
