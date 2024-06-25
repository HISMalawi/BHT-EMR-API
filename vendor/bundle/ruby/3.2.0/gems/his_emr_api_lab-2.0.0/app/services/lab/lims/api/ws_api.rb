# frozen_string_literal: true

require 'socket.io-client-simple'

module Lab
  module Lims
    module Api
      ##
      # Retrieve results from LIMS only through a websocket
      class WsApi
        def initialize(config)
          @config = config
          @results_queue = []
          @socket = nil
        end

        def consume_orders(**_kwargs)
          loop do
            results = fetch_results
            unless results
              Rails.logger.debug('No results available... Waiting for results...')
              sleep(Lab::Lims::Config.updates_poll_frequency)
              next
            end

            Rails.logger.info("Received result for ##{results['tracking_number']}")
            order = find_order(results['tracking_number'])
            next unless order

            Rails.logger.info("Updating result for order ##{order.order_id}")
            yield make_order_dto(order, results), OpenStruct.new(last_seq: 1)
          end
        end

        private

        def initialize_socket
          Rails.logger.debug('Establishing connection to socket...')
          socket = SocketIO::Client::Simple.connect(socket_url)
          socket.on(:connect, &method(:on_socket_connect))
          socket.on(:disconnect, &method(:on_socket_disconnect))
          socket.on(:results, &method(:on_results_received))
        end

        def socket_url
          @config.fetch('url')
        end

        def on_socket_connect
          Rails.logger.debug('Connection to LIMS results socket established...')
        end

        def on_socket_disconnect
          Rails.logger.debug('Connection to LIMS results socket lost...')
          @socket = nil
        end

        def on_results_received(result)
          Rails.logger.debug("Received result from LIMS: #{result}")
          tracking_number = result['tracking_number']

          Rails.logger.debug("Queueing result for order ##{tracking_number}")
          @results_queue.push(result)
        end

        def order_exists?(tracking_number)
          Rails.logger.debug("Looking for order for result ##{tracking_number}")
          orders = OrdersSearchService.find_orders_without_results
                                      .where(accession_number: tracking_number)
          # The following ensures that the order was previously pushed to LIMS
          # or was received from LIMS
          Lab::LimsOrderMapping.where.not(order: orders).exists?
        end

        def fetch_results
          loop do
            @socket ||= initialize_socket

            results = @results_queue.shift
            return nil unless results

            unless order_exists?(results['tracking_number'])
              Rails.logger.debug("Ignoring result for order ##{tracking_number}")
              next
            end

            return results
          end
        end

        def find_order(lims_id)
          mapping = Lab::LimsOrderMapping.where(lims_id:).select(:order_id)
          Lab::LabOrder.find_by(order_id: mapping)
        end

        def make_order_dto(order, results)
          Lab::Lims::OrderSerializer
            .serialize_order(order)
            .merge(
              id: order.accession_number,
              test_results: {
                results['test_name'] => {
                  results: results['results'].each_with_object({}) do |measure, formatted_measures|
                    measure_name, measure_value = measure

                    formatted_measures[measure_name] = { result_value: measure_value }
                  end,
                  result_date: results['date_updated'],
                  result_entered_by: {
                    first_name: results['who_updated']['first_name'],
                    last_name: results['who_updated']['last_name'],
                    id: results['who_updated']['id_number']
                  }
                }
              }
            )
        end
      end
    end
  end
end
